# @path: ~/projects/configs/nix-config/home/core/sys/env.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: home::core::sys::env

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    clang
    cmake
    rustc
    cargo
    python312
    nodejs_24
  ];
}


