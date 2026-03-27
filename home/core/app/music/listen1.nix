# @path: ~/projects/configs/nix-config/home/core/app/music/lx-music.nix
# @author: redskaber
# @datetime: 2026-02-14
# @description: home::core::app::music::listen1

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    listen1
  ];
}


