# @path: ~/projects/configs/nix-config/platform/nixos/core/base/impermanence.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: platform::nixos::core::base::impermanence — the ephemeral-root interpreter registration (T5.14)
#
# THE CAPABILITY, NOT THE DATA. This file does two things and nothing
# else:
#
#   1. registers impermanence's NixOS module for every nixos host —
#      the environment.persistence option surface (the inventory of
#      what survives), inert on hosts that declare nothing;
#   2. when a host declares `redskaber.impermanence.ephemeral-root
#      .enable = true`, DERIVES the btrfs subvolume-rollback recipe
#      from the facts the layout already declares — no restatement,
#      no hand-copied script.
#
# The third fact pair of the hosts/ data doctrine (facter T5.12,
# disko T5.13, impermanence T5.14):
#
#   hosts/<h>/persist.nix     the DATA — the state strategy: that the
#                             root is ephemeral, and the inventory of
#                             what survives (environment.persistence).
#   hosts/<h>/disk.nix        the DATA — the btrfs subvolume layout
#                             (which subvol mounts where).
#   THIS file                 the INTERPRETER — connects the two:
#                             reads the ROOT's derived mount facts
#                             (device, fsType, subvol — disko's
#                             _config output, or hand-written
#                             fileSystems), generates the rollback
#                             script, and enforces the contracts.
#
# The recipe is the upstream canonical one — impermanence's own
# README.org, "BTRFS subvolumes" section — with exactly two
# mechanical adaptations, both cited in place:
#   - the device/subvol/retention are interpolated from DECLARED
#     facts instead of hardcoded (this is what makes it an
#     interpreter instead of a snippet);
#   - the top-level view is mounted with `-o subvol=/` (the pinned
#     disko's own convention in its _create script), which stays
#     correct even if a default subvolume were ever set.
#
# TWO INTRD MODES, ONE RECIPE. The platform boots systemd stage 1
# (boot.nix: boot.initrd.systemd.enable = true — the fleet default),
# where `boot.initrd.postResumeCommands` does not exist (eval-time
# assertion in nixos' systemd/initrd.nix — the T5.14 verification
# battery hit exactly that). The recipe therefore lands as an initrd
# systemd oneshot, ordered before sysroot.mount and gated on the
# root device unit (the systemd-repart precedent for initrd services
# that must wait for a device). The classic-initrd branch keeps the
# upstream hook: postResumeCommands run before the fsInfo-driven
# mount loop (verified against the locked 26.05 stage-1-init.sh —
# the recipe must archive/re-create the root subvol before "/" is
# mounted on it). The mode dispatch is the interpreter's own concern
# over a DECLARED mode option — the nixpkgs task-module idiom
# (nixos/modules/tasks/filesystems/btrfs.nix branches the same way),
# not a host-layer conditional.
#
# btrfs-progs availability is NOT a hand-wired concern in either
# mode: nixos/modules/tasks/filesystems/btrfs.nix auto-derives from
# fileSystems fsTypes (root=persistent=nix=boot on btrfs ⇒ btrfs ∈
# boot.initrd.supportedFilesystems ⇒ classic: copied into
# extraUtils; systemd: initrdBin — which also carries coreutils and
# util-linux mount, verified against the locked tree).
#
# Boot chain integrity (the trap this design exists to avoid): /boot
# must NOT live on the ephemeral subvol or the second boot finds an
# empty /boot. The vm layout gives the boot chain its own persistent
# subvol (see hosts/vm/disk.nix). GRUB addresses btrfs paths from
# the top-level view, where a top-level subvol is a directory —
# /boot/grub resolves to the boot subvol's contents.
#
# Why the contracts live HERE and not in the data: upstream
# impermanence already asserts that every persistence path is
# neededForBoot; this interpreter SATISFIES that contract by
# deriving it (mkDefault — an explicit host override still wins),
# and adds the one assertion upstream is deliberately lenient
# about: in this tree every mount is a DECLARED layout fact, so a
# persistence path with no fileSystems entry is a layout gap and
# fails loudly here.
#
# The preservation verdict (recorded per the knowledge-search
# protocol): nix-community/preservation — impermanence's
# nixpkgs-track successor (nixpkgs#265640, "interpreter-less"
# state management) — was evaluated for T5.14 and NOT chosen:
# neither module is in the locked nixos-26.05 tree, so the T5.12
# zero-input precedent cannot apply yet, and the experiment
# deliberately rides the most battle-tested persistence module
# (impermanence: the canonical btrfs recipe is its own README).
# When preservation lands in a future nixpkgs, the migration is
# the T5.12 precedent verbatim: drop this input, swap the
# declaration surface in hosts/<h>/persist.nix — the inventory
# data and this rollback machinery are unaffected (they belong
# to the layout layer, not the persistence-module layer).
#
# No declaration, no effect: a host without persist.nix sees only
# inert options (enable defaults to false; environment.persistence
# stays empty). Verified in T5.14: the nixos host's config probes
# are bit-for-bit unchanged by this import; its toplevel drift
# traces to the flake self tree hash + lock node, the established
# funnel (T5.13).

{
  inputs,
  config,
  lib,
  utils,
  ...
}:

let
  cfg = config.redskaber.impermanence.ephemeral-root;

  # The root's mount facts — the disko interpreter's _config output
  # (or a hand-written fileSystems entry; the interpreter reads the
  # NixOS IR either way — the same surface `just disk-show` prints).
  rootFS = config.fileSystems."/";
  subvolOption = lib.lists.findFirst (o: lib.hasPrefix "subvol=" o) null rootFS.options;
  rootSubvol = if subvolOption == null then null else lib.removePrefix "subvol=" subvolOption;

  # The persistence inventory, enabled entries only (impermanence
  # lets a declaration sit disabled for sharing configs across
  # machine kinds — those are not this machine's contract).
  enabledPersistence = lib.filterAttrs (_: p: p.enable) config.environment.persistence;

  # The rollback recipe — one body, two initrd modes (see header).
  # Upstream impermanence README.org ("BTRFS subvolumes"),
  # device/subvol/retention interpolated from the declared facts.
  # First boot: no root subvol and no old_roots/ exist — the `if`
  # and the `find` skip harmlessly. POSIX sh: classic stage 1 and
  # the systemd oneshot run it under equivalent userlands.
  recipe = ''
    mkdir /btrfs_tmp
    mount ${rootFS.device} /btrfs_tmp -o subvol=/
    if [[ -e /btrfs_tmp/${rootSubvol} ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/${rootSubvol})" "+%Y-%m-%-d_%H:%M:%S")
        mv /btrfs_tmp/${rootSubvol} "/btrfs_tmp/old_roots/$timestamp"
    fi

    delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs_tmp/$i"
        done
        btrfs subvolume delete "$1"
    }

    for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +${toString cfg.retain-days}); do
        delete_subvolume_recursively "$i"
    done

    btrfs subvolume create /btrfs_tmp/${rootSubvol}
    umount /btrfs_tmp
  '';

  # The root device as a systemd device unit — the wait-gate for
  # the systemd-mode oneshot (same escapeSystemdPath convention as
  # nixos' systemd-repart initrd service).
  rootDeviceUnit = "${utils.escapeSystemdPath rootFS.device}.device";
in
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  options.redskaber.impermanence.ephemeral-root = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Roll back the btrfs root subvolume on every boot: the old
        root is archived under an old_roots/ subvolume (timestamped),
        roots older than retain-days are deleted recursively, and a
        fresh empty root subvolume is created before / is mounted.
        Requires the root filesystem to be btrfs mounted from a
        subvolume, and every enabled environment.persistence path to
        be a declared mount (this interpreter derives neededForBoot
        for them).
      '';
    };

    retain-days = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = ''
        Days an archived root survives before the recursive cleanup
        deletes it (upstream recipe default: 30).
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = rootFS.fsType == "btrfs";
            message = ''
              redskaber.impermanence.ephemeral-root is enabled but the root
              filesystem is ${toString rootFS.fsType} — the subvolume rollback
              recipe is btrfs-only (upstream impermanence: tmpfs or ZFS are
              the other ephemeral-root strategies, not declared here).
            '';
          }
          {
            assertion = rootSubvol != null;
            message = ''
              redskaber.impermanence.ephemeral-root is enabled but the root
              mount carries no subvol= option — rolling back the top level
              would archive every subvolume (the store, the state, the boot
              chain) with it. Declare the root as a subvolume in
              hosts/<h>/disk.nix.
            '';
          }
          {
            assertion = lib.all (path: builtins.hasAttr path config.fileSystems) (
              builtins.attrNames enabledPersistence
            );
            message = ''
              redskaber.impermanence.ephemeral-root: an enabled
              environment.persistence path is not a declared mount. In this
              tree every mount is a layout fact (hosts/<h>/disk.nix) —
              persisting into an undeclared path is a layout gap, not a
              tmpfs-root pattern.
            '';
          }
        ];

        # Satisfy upstream's "every persistence path is neededForBoot"
        # contract by derivation: the data declares WHAT survives, the
        # interpreter wires WHEN it must be mounted (early — activation
        # and the machine-id bind depend on it). mkDefault keeps an
        # explicit host override authoritative.
        fileSystems = lib.mapAttrs' (
          path: _:
          lib.nameValuePair path {
            neededForBoot = lib.mkDefault true;
          }
        ) enabledPersistence;
      }

      # ── systemd stage 1 (the platform fleet default) ──────────────
      # A oneshot before sysroot.mount: the old root is archived and
      # the fresh subvol created before "/" is mounted on it. Gated
      # on the root device unit (udev must have it before we mount
      # the top-level view); DefaultDependencies=false — initrd units
      # have no sysinit to lean on.
      (lib.mkIf config.boot.initrd.systemd.enable {
        boot.initrd.systemd.services.ephemeral-root = {
          description = "Archive the ephemeral btrfs root, create a fresh one";
          wantedBy = [ "initrd-root-fs.target" ];
          before = [
            "sysroot.mount"
            "initrd-root-fs.target"
          ];
          after = [ rootDeviceUnit ];
          wants = [ rootDeviceUnit ];
          unitConfig.DefaultDependencies = false;
          serviceConfig.Type = "oneshot";
          script = recipe;
        };
      })

      # ── classic stage 1 ────────────────────────────────────────────
      # The upstream hook: postResumeCommands run before the
      # fsInfo-driven mount loop (locked 26.05 stage-1-init.sh).
      (lib.mkIf (!config.boot.initrd.systemd.enable) {
        boot.initrd.postResumeCommands = lib.mkAfter recipe;
      })
    ]
  );
}
