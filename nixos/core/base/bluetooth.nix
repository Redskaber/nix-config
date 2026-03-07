# @path: ~/projects/configs/nix-config/nixos/core/base/bluetooth.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::base::bluetooth


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;
  hardware.bluetooth.settings = {
    General = {
      Enable = "Source,Sink,Media,Socket";
      Experimental = true;
    };
  };
  environment.systemPackages = with pkgs; [
    overskride
  ];

}


