# @path: ~/projects/configs/nix-config/nixos/core/srv/hardware/bluetooth.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::hardware::bluetooth


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  services = {
    # Input, bluetooth
    libinput.enable = true;
    blueman.enable = true;
  };
}


