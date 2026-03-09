# @path: ~/projects/configs/nix-config/nixos/core/exp/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::exp::default

{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    ./clash-verge.nix
    ./compat.nix
    ./core.nix
    ./obs.nix
    ./steam.nix
  ];


}


