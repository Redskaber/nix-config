# @path: ~/projects/configs/nix-config/platform/nixos/core/base/disk.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: platform::nixos::core::base::disk — the disk-layout interpreter registration (T5.13)
#
# THE CAPABILITY, NOT THE DATA. This file registers disko's NixOS module
# for every nixos host; the LAYOUTS themselves live as host facts in
# hosts/<h>/disk.nix (whoever's disks, whoever declares — the same
# frontend/backend split as the facter report, T5.12):
#
#   hosts/<h>/disk.nix          the DATA — disko.devices (partitions,
#                               filesystems, mountpoints). Absent on
#                               hosts that have not migrated yet.
#   THIS file                   the INTERPRETER — translates a layout
#                               into NixOS options (fileSystems,
#                               swapDevices, boot.loader.grub.devices)
#                               and into the format/mount scripts
#                               (config.system.build.*).
#
# Precedents, both already in this tree: sops-nix is registered here in
# core/sec/secret (module = capability, platform-side); the facter
# module is registered upstream in nixpkgs' default module list. disko
# is not in nixpkgs (checked against the locked 26.05 tree), so WE own
# its registration — same rule, one more owner. The dispatch layer and
# flake.nix stay untouched by all of this (the input is registered in
# flake.nix, imported here, consumed per-host).
#
# No layout, no effect: a host without hosts/<h>/disk.nix keeps
# disko.devices at its empty default — the module then contributes
# only inert options and lazy scripts to system.build. fileSystems/
# swapDevices merge as empty attrsets/lists, so an undeclaring host's
# configuration and closure are bit-for-bit what they were without
# this import (verified in T5.13: hosts/nixos toplevel funnel diff
# traces exclusively to the flake self-registry entry).
#
# The module's one wired default worth knowing: a GPT layout that
# declares an EF02 (BIOS boot) partition makes disko set
# boot.loader.grub.devices — the BIOS counterpart of systemd-boot's
# ESP conventions. UEFI hosts (the real machine) declare no EF02 and
# keep the platform loader policy from ./boot.nix untouched.

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
