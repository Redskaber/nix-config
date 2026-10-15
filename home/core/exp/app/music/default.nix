# @path: ~/projects/configs/nix-config/home/core/exp/app/music/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @directory: https://nix-community.github.io/home-manager/options.xhtml
# @derivation: home::core::exp::app::music
# @description: 统一音乐生态系统配置 (MPD + ncurses客户端 + 音频增强)
#
# 统一音乐生态系统 (MPD + ncurses 客户端 + 音频增强)：
#   MPD — 127.0.0.1:6600，音乐库 ~/Music，播放列表 ~/.local/share/mpd。
#   EasyEffects — 音频增强 (30 段均衡器)，预设 "music"，GUI 可调。
#   MPRIS 代理 — 蓝牙媒体键桥接 (依赖系统级 bluez)。
# 路径遵循 XDG 规范：配置 ~/.config/{app}、数据 ~/.local/share/{app}、
# 缓存 ~/.cache/{app}。

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
let
  # ===== 统一路径定义 (集中管理) =====
  paths = {
    musicDir = "${config.home.homeDirectory}/Music"; # 主音乐库目录
  };

  # The whole music ecosystem rides on the Linux audio stack — darwin
  # gets its stack from the OS. One gate at the ROUTER keeps every leaf
  # unconditional; darwin skips this subtree. (module-position mkIf is
  # illegal: body under `config = lib.mkIf`, imports under
  # `lib.optionals`.)
  isLinuxFamily = shared.caps.linux-family;
in
{
  imports = lib.optionals isLinuxFamily [
    ./cnmplayer.nix
    ./easyeffects.nix
    ./mpd.nix
    ./playerctld.nix
    ./spotify.nix
  ];

  config = lib.mkIf isLinuxFamily {
    # ===== 目录初始化 =====
    home.activation.ensureMusicDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # 创建音乐库目录
      mkdir -p "${paths.musicDir}"
    '';

    # ===== XDG 用户目录规范 =====
    xdg.userDirs = {
      enable = true;
      music = paths.musicDir; # 标准化音乐目录位置
    };

    # ===== 实用工具包 =====
    home.packages = with pkgs; [
      pulsemixer # 终端音量控制 (pulsemixer)
      pavucontrol # pulseaudio 高级控制面板
      alsa-utils # alsa 底层工具 (alsamixer/amixer)
      yt-dlp # 音频下载工具 (yt-dlp -x --audio-format mp3 url)
    ];

  };

}
