# @path: ~/projects/configs/nix-config/tests/nixos/core/base/impermanence.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: tests::nixos::core::base::impermanence
# @source: platform/nixos/core/base/impermanence.nix
#
# Eval-level acceptance of the ephemeral-root interpreter (T5.14),
# the export-modules.nix pattern applied to a fixpoint module: the
# production module is imported into standalone nixosSystem
# evaluations (the exact path an external consumer would take —
# real module system, real NixOS option surface), and the contract
# checks are plain eval-time asserts in the let.
#
# Three evaluations, three laws:
#
#   systemd — declared ephemeral root under systemd stage 1 (the
#     platform fleet default, boot.nix): the rollback recipe lands
#     as an initrd oneshot ordered before sysroot.mount, gated on
#     the root device unit; neededForBoot derived for the
#     persistence path; upstream impermanence turned the inventory
#     into bind mounts.
#
#   classic — the same declaration under classic stage 1: the
#     recipe lands in postResumeCommands (the upstream hook, which
#     runs before the root mount loop).
#
#   inert — the module imported, persistence data declared, but NO
#     ephemeral-root declaration: ZERO rollback behavior in either
#     surface (the "no declaration, no effect" law — a
#     persistent-root host may still use environment.persistence
#     as bind-mount convenience; its /persistent is neededForBoot
#     by its own declaration, which upstream impermanence asserts
#     regardless of us).
#
# The facts are hand-written in the shape disko derives for hosts/vm
# (btrfs subvolumes by mountpoint) so the test does not depend on
# the vm host's policy chain. Boot-level acceptance of the rollback
# itself is the CI vm-tests stage / a KVM environment (README
# known-debt #8); what this test pins is everything above boot:
# the interpreter's derivation and its inertness.

{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  nixosSystem = inputs.nixpkgs.lib.nixosSystem;

  base = [
    { nixpkgs.hostPlatform = "x86_64-linux"; }
    {
      # The btrfs subvolume layout as disko derives it for hosts/vm
      # (see hosts/vm/disk.nix): root/persistent/nix/boot subvols on
      # one device, addressed by GPT partlabel there, plain device
      # here — the interpreter only reads the derived mount facts.
      fileSystems."/" = {
        device = "/dev/vda2";
        fsType = "btrfs";
        options = [
          "defaults"
          "subvol=root"
        ];
      };
      fileSystems."/persistent" = {
        device = "/dev/vda2";
        fsType = "btrfs";
        options = [
          "defaults"
          "subvol=persistent"
        ];
      };
      fileSystems."/nix" = {
        device = "/dev/vda2";
        fsType = "btrfs";
        options = [
          "defaults"
          "subvol=nix"
        ];
      };
      fileSystems."/boot" = {
        device = "/dev/vda2";
        fsType = "btrfs";
        options = [
          "defaults"
          "subvol=boot"
        ];
      };
    }
  ];

  # ── declared, systemd stage 1 (the fleet default) ──────────────
  systemdEval = nixosSystem {
    specialArgs = { inherit inputs; };
    modules = base ++ [
      ../../../../platform/nixos/core/base/impermanence.nix
      {
        boot.initrd.systemd.enable = true;
        redskaber.impermanence.ephemeral-root = {
          enable = true;
          retain-days = 30;
        };
        environment.persistence."/persistent" = {
          directories = [ "/var/log" ];
          files = [ "/etc/machine-id" ];
        };
      }
    ];
  };

  # ── declared, classic stage 1 — the upstream hook surface ────
  classicEval = nixosSystem {
    specialArgs = { inherit inputs; };
    modules = base ++ [
      ../../../../platform/nixos/core/base/impermanence.nix
      {
        boot.initrd.systemd.enable = false;
        redskaber.impermanence.ephemeral-root.enable = true;
        environment.persistence."/persistent" = {
          directories = [ "/var/log" ];
        };
      }
    ];
  };

  # ── inert: persistence declared, root NOT ephemeral ─────────────
  inertEval = nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      ../../../../platform/nixos/core/base/impermanence.nix
      {
        fileSystems."/" = {
          device = "/dev/vda2";
          fsType = "ext4";
          options = [ "defaults" ];
        };
        fileSystems."/persistent" = {
          device = "/dev/vda3";
          fsType = "ext4";
          neededForBoot = true; # upstream impermanence asserts this
        };
        environment.persistence."/persistent" = {
          directories = [ "/var/log" ];
        };
      }
    ];
  };

  # ── Eval-time assertions ─────────────────────────────────────────
  systemdSvc = systemdEval.config.boot.initrd.systemd.services.ephemeral-root;
  classicRecipe = classicEval.config.boot.initrd.postResumeCommands;

  evalAssertions =
    # systemd mode: the recipe is an initrd oneshot, interpolated from
    # the declared facts, ordered before the root mount and gated on
    # the root device unit (the systemd-repart convention).
    assert lib.hasInfix "btrfs subvolume create /btrfs_tmp/root" systemdSvc.script;
    assert lib.hasInfix "mount /dev/vda2 /btrfs_tmp -o subvol=/" systemdSvc.script;
    assert lib.hasInfix "mv /btrfs_tmp/root \"/btrfs_tmp/old_roots/$timestamp\"" systemdSvc.script;
    assert lib.hasInfix "mtime +30" systemdSvc.script;
    assert lib.elem "sysroot.mount" systemdSvc.before;
    assert lib.elem "initrd-root-fs.target" (systemdSvc.wantedBy or [ ]);
    assert lib.elem "dev-vda2.device" systemdSvc.after;
    assert systemdSvc.unitConfig.DefaultDependencies == false;
    assert systemdSvc.serviceConfig.Type == "oneshot";
    # the interpreter derived neededForBoot for the persistence path
    assert systemdEval.config.fileSystems."/persistent".neededForBoot == true;
    # upstream impermanence turned the inventory into a bind mount
    assert lib.any (m: m.where == "/var/log") systemdEval.config.systemd.mounts;
    # classic mode: the same recipe through the upstream hook
    assert lib.hasInfix "btrfs subvolume create /btrfs_tmp/root" classicRecipe;
    assert lib.hasInfix "mount /dev/vda2 /btrfs_tmp -o subvol=/" classicRecipe;
    # inert mode: no declaration, no effect — in EITHER surface
    assert !lib.hasInfix "btrfs subvolume" inertEval.config.boot.initrd.postResumeCommands;
    assert !(inertEval.config.boot.initrd.systemd.services ? "ephemeral-root");
    "eval-assertions-passed";
in
{
  name = "nixos_core_base_impermanence";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 60;
  };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("impermanence: interpreter derives the rollback, stays inert undeclared"):
        # ${evalAssertions} — renders only if the interpreter derived
        # the recipe correctly in both initrd modes and contributed
        # nothing to the undeclared machine.
        machine.succeed("true")
  '';
}
