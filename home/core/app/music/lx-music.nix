# @path: ~/projects/configs/nix-config/home/core/app/music/mpd.nix
# @author: redskaber
# @datetime: 2026-02-14
# @description: home::core::app::music::mpd

{ inputs
, lib
, config
, pkgs
, ...
}:
{
  # ===== 实用工具包 =====
  home.packages = with pkgs; [
    lx-music-desktop # 基于 electron 和 vue 的音乐软件 (free)
  ];
}


