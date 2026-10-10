# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/hardware/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::srv::hardware::default

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./bluetooth.nix
    ./firmware.nix
    ./power.nix
    ./printing.nix
    ./storage.nix
  ];

}
