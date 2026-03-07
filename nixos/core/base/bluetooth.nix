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
  # enable bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.poweronboot = false;
  hardware.bluetooth.settings = {
    general = {
      enable = "source,sink,media,socket";
      experimental = true;
    };
  };
  environment.systempackages = with pkgs; [
    overskride
  ];

}


