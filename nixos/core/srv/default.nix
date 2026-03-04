# @path: ~/projects/configs/nix-config/nixos/core/srv/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::default


{ inputs
, shared
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


