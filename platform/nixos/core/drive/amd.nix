# @path: ~/projects/configs/nix-config/platform/nixos/core/drive/amd.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::drive::amd
#
# Reachable via drive-group enum: amd / amd-nvidia / amd-nvidia-prime.
# Intentionally empty: AMD GPUs work out of the box with Mesa/radeonsi
# (hardware.graphics in core/base); no vendor driver module is required.
# Keep this file — the drive router imports ./${drive}.nix unconditionally.

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
}
