# @path: ~/projects/configs/nix-config/platform/nixos/system/core/base/disk.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: platform::nixos::core::base::disk — the disk-layout interpreter registration
#
# THE CAPABILITY, NOT THE DATA: this file registers disko's NixOS
# module for every nixos host; the LAYOUTS live as host facts in
# hosts/<h>/disk.nix — disko.devices (partitions, filesystems,
# mountpoints) — which the module translates into NixOS options
# (fileSystems, swapDevices, boot.loader.grub.devices) and the
# format/mount scripts (config.system.build.*). disko is not in
# nixpkgs, so WE own its registration — the same rule as sops-nix
# in core/sec/secret (module = capability, platform-side); the
# facter module rides nixpkgs' default module list.
#
# No layout, no effect: a host without hosts/<h>/disk.nix keeps
# disko.devices at its empty default — only inert options and lazy
# scripts; fileSystems/swapDevices merge empty, so the configuration
# and closure are unchanged.
#
# The module's one wired default worth knowing: a GPT layout that
# declares an EF02 (BIOS boot) partition makes disko set
# boot.loader.grub.devices — the BIOS counterpart of systemd-boot's
# ESP conventions. UEFI hosts declare no EF02 and keep the platform
# loader policy from ./boot.nix untouched.

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ inputs.disko.nixosModules.disko ];
}
