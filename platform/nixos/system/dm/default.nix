# @path: ~/projects/configs/nix-config/platform/nixos/system/dm/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::dm::default

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./${shared.display-manager.tag}
  ];
}
