# @path: ~/projects/configs/nix-config/hosts/vm/default.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: hosts::vm — virtual machine host facts (facter path, T5.12)
#
# Eval-level second machine (T2.5): this host exists to prove that one
# flake evaluates two machines from two different policy files (see
# hosts/vm/shared.nix). Boot-level validation runs under KVM in the CI
# vm-tests stage; this sandbox has no /dev/kvm, so acceptance here is
# evaluation depth (toplevel derivation + policy discriminators verified).
#
# Machine facts, two data files and one wiring line per source:
#
#   ./facter.json (T5.12 — nixos-facter): the hardware shape as a
#   report — interpreted by the nixpkgs `hardware.facter` module (in
#   the default module list), wired below. The report drives
#   everything a report CAN drive —
#
#     report.system          → nixpkgs.hostPlatform (mkDefault — the
#                              report is the single source of the
#                              platform fact)
#     report.virtualisation  → virtio/guest handling ("kvm": qemu-class
#                              virtio modules land in the initrd)
#     disk/storage_controller driver_modules
#                            → boot.initrd.availableKernelModules
#     report.uefi           → boot-loader hints (BIOS guest: none)
#     network_interface     → omitted from the report on purpose: the
#                              platform's NetworkManager policy owns
#                              DHCP (platform/nixos/core/base/network.nix);
#                              the CONTROLLER (virtio-net) is declared —
#                              the driver still reaches the initrd.
#
#   ./disk.nix (T5.13 — disko): the disk shape as a layout —
#   interpreted by the disko module (registered platform-side in
#   platform/nixos/core/base/disk.nix), imported below. The layout
#   drives fileSystems, and its EF02 partition wires
#   boot.loader.grub.devices (the BIOS-boot story; the loader policy
#   override rides along in the same file — see its header).
#
# The real machine (hosts/nixos) migrates the same way ON the machine:
# `just hardware-facter` for the report; for the disk layout, on the
# next reinstall write hosts/nixos/disk.nix and apply it from the
# installer (`just disk-format nixos`). See README §hosts.

{ ... }:

{
  imports = [
    # T5.13 — the disk layout (disko data; interpreter platform-side).
    ./disk.nix
  ];

  # Declarative hardware report — the nixpkgs facter module derives the
  # virtio initrd modules, hostPlatform and guest handling from this data.
  hardware.facter.reportPath = ./facter.json;

  # QEMU guest agent for the CI VM stages.
  services.qemuGuest.enable = true;
}
