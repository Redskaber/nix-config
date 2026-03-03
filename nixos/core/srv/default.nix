# @path: ~/projects/configs/nix-config/nixos/core/srv/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::default


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    ./db
    ./desktop
    ./hardware
    ./log
    ./security
  ];


}


