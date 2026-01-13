# @path: ~/projects/configs/nix-config/nixos/core/bluetooth.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::bluetooth


{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;
  environment.systemPackages = with pkgs; [
    overskride
  ];

}


