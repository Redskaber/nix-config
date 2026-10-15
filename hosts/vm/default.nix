# @path: ~/projects/configs/nix-config/hosts/vm/default.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: hosts::vm — virtual machine host facts (facter, disk, persist)
#
# Eval-level machine: proves one flake evaluates two machines from
# two different policy files (hosts/vm/shared.nix). Boot-level
# validation runs under KVM in the CI vm-tests stage.
#
# Machine facts, two data files and one wiring line per source:
#
#   ./facter.json (nixos-facter): the hardware shape as a report —
#   interpreted by the nixpkgs `hardware.facter` module, wired below.
#   The report drives everything a report CAN drive — system →
#   nixpkgs.hostPlatform (mkDefault); virtualisation → virtio/guest
#   handling; disk/storage_controller driver_modules → initrd modules;
#   uefi → boot-loader hints (BIOS guest: none). network_interface is
#   omitted on purpose: the platform's NetworkManager policy owns
#   DHCP (the CONTROLLER virtio-net is declared — the driver still
#   reaches the initrd).
#
#   ./disk.nix (disko): the disk shape as a layout — interpreter
#   platform-side (platform/nixos/system/core/base/disk.nix), imported
#   below. Drives fileSystems; its EF02 partition wires
#   boot.loader.grub.devices (the BIOS-boot story; the loader policy
#   override rides along in the same file — see its header).
#
#   ./persist.nix (impermanence): the state strategy — that the root
#   is ephemeral, and the inventory of what survives — interpreter +
#   rollback machinery platform-side, imported below. Together with
#   the btrfs subvolume layout in ./disk.nix this makes the guest an
#   ephemeral-root machine.
#
# The real machine (hosts/nixos) migrates the same way ON the machine:
# `just hardware-facter` for the report; for the disk layout, on the
# next reinstall write hosts/nixos/disk.nix and apply it from the
# installer (`just disk-format nixos`). See README §hosts.

{ ... }:

{
  imports = [
    # the disk layout (disko data; interpreter platform-side).
    ./disk.nix
    # the state strategy (impermanence data; interpreter platform-side).
    ./persist.nix
  ];

  # Declarative hardware report — the nixpkgs facter module derives the
  # virtio initrd modules, hostPlatform and guest handling from this data.
  hardware.facter.reportPath = ./facter.json;

  # QEMU guest agent for the CI VM stages.
  services.qemuGuest.enable = true;
}
