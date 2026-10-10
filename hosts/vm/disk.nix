# @path: ~/projects/configs/nix-config/hosts/vm/disk.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: hosts::vm::disk — the guest's one-disk layout (disko, T5.13; btrfs subvolumes, T5.14)
#
# THE DATA half of the disk fact pair (interpreter lives platform-side
# in platform/nixos/core/base/disk.nix). T5.13 declared the whole disk
# as a GPT partition table with an EF02 BIOS-boot staging partition
# and a root ext4; T5.14 upgrades the root partition to btrfs so the
# root can become EPHEMERAL — four subvolumes, four lifetimes:
#
#   root       mounted at /           EPHEMERAL — archived under
#            old_roots/<timestamp> and re-created empty on every boot
#            by the rollback interpreter
#            (platform/nixos/core/base/impermanence.nix). Anything on
#            it that is not in /persistent evaporates at boot.
#   persistent  mounted at /persistent  THE STATE — what survives
#            (the inventory lives in ./persist.nix; the interpreter
#            derives neededForBoot).
#   nix        mounted at /nix         THE STORE — the system closure
#            outlives the root; compress=zstd (the store is highly
#            compressible; GRUB never reads it).
#   boot       mounted at /boot        THE BOOT CHAIN — kernels,
#            initrds and grub.cfg must survive the rollback or the
#            second boot finds an empty /boot. GRUB addresses btrfs
#            from the top-level view, where a subvolume is a
#            directory — /boot/grub resolves into this subvol.
#
# Compression policy: compress=zstd ONLY on /nix. /persistent stays
# uncompressed on purpose — PostgreSQL's reliability guidance flags
# compressed btrfs for the data directory, and postgres is this
# machine's one real service (server-pg-only profile). The ephemeral
# root gets noatime-free plain defaults: its contents die at boot
# anyway. /boot stays minimal too — grub's btrfs reader is the most
# conservative code in the boot chain.
#
# Everything else from T5.13 stands unchanged: the EF02 partition
# wires boot.loader.grub.devices (disko's rule: GPT + BIOS-boot
# partition → grub on the whole disk); the device is addressed by
# GPT partlabel (stable across re-plumbing); boot POLICY stays with
# the platform, the host only overrides what its facts contradict
# (BIOS guest, uefi false in facter.json).
#
# Apply-from-installer (fresh installs / reinstalls): `just
# disk-format vm` builds and runs the pinned disko format+mount
# script. DESTRUCTIVE — it partitions and formats /dev/vda. After a
# fresh format the rollback script's first boot just creates the
# root subvol (the `if` skips; find on missing old_roots/ no-ops).

{ lib, ... }:

{
  # The guest's one-disk layout: GPT with a BIOS-boot staging partition
  # and a btrfs root filling the rest — four subvolumes, four
  # lifetimes (see header).
  disko.devices.disk.vda = {
    device = "/dev/vda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        # EF02 (BIOS boot): 1MiB of core.img staging — required for
        # grub's i386-pc install on a GPT disk; flagged "required".
        boot = {
          size = "1M";
          type = "EF02";
          attributes = [ 0 ];
        };
        # Root filesystem — the whole remaining disk, btrfs.
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            # -f: mkfs.btrfs refuses to overwrite an existing
            # filesystem without it. The format script is destructive
            # by contract (see disk.just) — re-installs re-forced.
            extraArgs = [ "-f" ];
            subvolumes = {
              # The ephemeral root (T5.14) — subvol name "root": the
              # rollback recipe in the interpreter references it as
              # the top-level child directory it archives/re-creates.
              root = {
                mountpoint = "/";
                mountOptions = [ "defaults" ];
              };
              # The state subvol — neededForBoot derived by the
              # persistence interpreter (contract with
              # environment.persistence in ./persist.nix).
              persistent = {
                mountpoint = "/persistent";
                mountOptions = [
                  "defaults"
                  "noatime"
                ];
              };
              # The store subvol — the closure outlives the root.
              nix = {
                mountpoint = "/nix";
                mountOptions = [
                  "defaults"
                  "noatime"
                  "compress=zstd"
                ];
              };
              # The boot chain's own persistent subvol — kernels and
              # grub.cfg must never ride the ephemeral root.
              boot = {
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
    };
  };

  # Boot-policy alignment (host fact: BIOS guest, uefi false in the
  # facter report). The platform defaults fit the UEFI fleet; this
  # host's facts contradict exactly two of them. grub.devices itself
  # is NOT set here — the EF02 partition above is what wires it
  # (structure over re-statement: the layout is the single source).
  # boot.loader.efi.canTouchEfiVariables stays true (platform default)
  # deliberately: with grub efiSupport off it is consumed by no loader
  # on this host — flipping it would be policy churn with no effect.
  boot.loader.grub.enable = true;
  boot.loader.systemd-boot.enable = lib.mkForce false;
}
