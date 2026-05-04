# @path: ~/projects/configs/nix-config/home/core/app/music/cnmplayer.nix
# @author: redskaber
# @datetime: 2026-04-22
# @description: home::core::app::music::cnmplayer
# A TUI Netease Cloud Music Player, with audio visualization and almost complete functions.

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    inputs.cnmplayer.packages.${shared.arch.tag}.default  # github package nix
  ];

}


