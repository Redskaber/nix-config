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
    ./compat.nix
    ./obs.nix
    ./steam.nix
  ];


}


