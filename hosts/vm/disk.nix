# @path: ~/projects/configs/nix-config/hosts/vm/disk.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: hosts::vm::disk — the guest's one-disk layout (disko, T5.13)
#
# THE DATA half of the disk fact pair (interpreter lives platform-side
# in platform/nixos/core/base/disk.nix). The layout replaces what the
# host entry used to hand-write —
#
#   fileSystems."/" = { device = "/dev/vda1"; fsType = "ext4"; };
#
# — with a DECLARATION of the whole disk: the partition table, the
# partition purposes, the filesystem. The interpreter derives the same
# three NixOS facts from it (the only deltas: the device is addressed
# by GPT partlabel — stable across re-plumbing, unlike /dev/vda1 — and
# mountOptions defaults to ["defaults"]):
#
#   disko.devices.disk.vda.content.partitions.root.content
#                          → fileSystems."/" (device by-partlabel,
#                            fsType ext4, options ["defaults"])
#   the EF02 partition     → boot.loader.grub.devices = ["/dev/vda"]
#                            (disko's rule: a GPT layout that declares
#                            a BIOS-boot partition gets grub wired to
#                            the whole disk — the MBR install point)
#
# The shape follows upstream's gpt-bios-compat example, and the fact
# chain hangs together: hosts/vm/facter.json reports uefi false (BIOS
# guest), so the layout declares the BIOS story — EF02 staging for
# grub's core.img, root on ext4, no ESP. Boot POLICY stays with the
# platform (systemd-boot for the UEFI fleet, ./boot.nix); the host
# only overrides the two options its facts contradict, mirroring how
# hosts/nixos sinks its NVIDIA bus IDs below the hardware-agnostic
# drive layer.
#
# Apply-from-installer (fresh installs / reinstalls): the layout is
# executable — `just disk-format vm` builds and runs the pinned
# disko-format-mount script (see scripts/just/disk.just). Destructive:
# it partitions and formats /dev/vda.

{ lib, ... }:

{
  # The guest's one-disk layout: GPT with a BIOS-boot staging partition
  # and a root ext4 filling the rest.
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
        # Root filesystem — the whole remaining disk.
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            mountOptions = [ "defaults" ];
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
