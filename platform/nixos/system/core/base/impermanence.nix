# @path: ~/projects/configs/nix-config/platform/nixos/system/core/base/impermanence.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: platform::nixos::core::base::impermanence — the ephemeral-root interpreter registration
#
# THE CAPABILITY, NOT THE DATA. This file registers impermanence's
# NixOS module for every nixos host, and when a host declares
# `redskaber.impermanence.ephemeral-root.enable = true` DERIVES the
# btrfs subvolume-rollback recipe from the facts the layout already
# declares — no restatement, no hand-copied script.
#
#   hosts/<h>/persist.nix   the DATA — the state strategy: that the
#                           root is ephemeral + the inventory of what
#                           survives (environment.persistence).
#   hosts/<h>/disk.nix      the DATA — the btrfs subvolume layout.
#   THIS file               the INTERPRETER — reads the root's derived
#                           mount facts (disko's _config output or
#                           hand-written fileSystems), generates the
#                           rollback script, enforces the contracts.
#
# The recipe is the upstream canonical one (impermanence README.org,
# "BTRFS subvolumes") with the device/subvol/retention interpolated
# from DECLARED facts, and the top-level view mounted `-o subvol=/`
# (the pinned disko's own convention — stays correct even if a
# default subvolume were ever set).
#
# TWO INITRD MODES, ONE RECIPE. The platform boots systemd stage 1
# (the fleet default), where boot.initrd.postResumeCommands does
# not exist — the recipe lands as an initrd systemd oneshot,
# ordered before sysroot.mount and gated on the root device unit;
# the classic-initrd branch keeps the upstream hook
# (postResumeCommands run before the fsInfo-driven mount loop).
# btrfs-progs availability is auto-derived by nixpkgs from
# fileSystems fsTypes — not a hand-wired concern in either mode.
#
# Boot chain integrity (the trap this design exists to avoid): /boot
# must NOT live on the ephemeral subvol or the second boot finds an
# empty /boot — the vm layout gives the boot chain its own persistent
# subvol (see hosts/vm/disk.nix).
#
# Why the contracts live HERE and not in the data: upstream
# impermanence already asserts every persistence path is
# neededForBoot — this interpreter SATISFIES that by derivation
# (mkDefault — an explicit host override still wins) and adds the
# one assertion upstream is lenient about: a persistence path with
# no fileSystems entry is a layout gap and fails loudly.
#
# preservation (impermanence's nixpkgs-track successor,
# "interpreter-less" state management) was evaluated and NOT chosen:
# neither module is in the locked nixos-26.05 tree. When preservation
# lands in a future nixpkgs, the migration is — drop this input,
# swap the declaration surface in hosts/<h>/persist.nix; the
# inventory data and this rollback machinery are unaffected (they
# belong to the layout layer, not the persistence-module layer).
#
# No declaration, no effect: a host without persist.nix sees only
# inert options (enable defaults to false; environment.persistence
# stays empty).

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
