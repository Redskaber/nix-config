# @path: ~/projects/configs/nix-config/nixos/core/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::default


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    ./base
    ./drive
    ./exp
    ./sec
    ./srv
  ];


}


