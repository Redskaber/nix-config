# @path: ~/projects/configs/nix-config/home/env/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::env::default

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./base
  ];
}


