# @path: ~/projects/configs/nix-config/nixos/core/srv/hardware/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::hardware::default


{ inputs
, config
, lib
, pkgs
, ...
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


