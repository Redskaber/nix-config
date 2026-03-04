# @path: ~/projects/configs/nix-config/home/core/app/music.nix
# @author: redskaber
# @datetime: 2025-12-12
# @directory: https://nix-community.github.io/home-manager/options.xhtml
# @derivation: home::core::app::music
# @description: 统一音乐生态系统配置 (MPD + ncurses客户端 + 音频增强)
#
# ========================================================================
# 核心组件说明
# ========================================================================
# 1. MPD (Music Player Daemon)
#    - 本地音乐服务核心，管理音乐库和播放队列
#    - 服务地址: 127.0.0.1:6600
#    - 音乐目录: ~/Music
#    - 播放列表: ~/.local/share/mpd/playlists
#
# 2. ncmpcpp
#    - ncurses 界面 MPD 客户端
#    - 特性: 音频可视化 (频谱/波形)、歌词显示
#    - 快捷键:
#        Enter - 播放/暂停
#        j/k   - 上下移动
#        J/K   - 选择+移动
#        ,/.   - 快退/快进10秒
#        1-8   - 切换标签页 (1:播放列表, 2:文件浏览器, 8:可视化)
#        u     - 更新音乐数据库
#
# 3. EasyEffects
#    - 音频增强系统 (30段均衡器 + 低音增强)
#    - 预设: "music" (专为音乐优化)
#    - 配置工具: 安装后运行 `easyeffects` GUI 调整
#
# 4. MPRIS 代理
#    - 蓝牙设备媒体控制桥接 (依赖系统级 bluez)
#    - 支持设备: 蓝牙耳机/键盘媒体键
#
# ========================================================================
# 标准化路径管理 (统一前缀)
# ========================================================================
# 所有音乐相关路径遵循 XDG 规范:
# - 音乐文件: ~/Music
# - 服务数据: ~/.local/share/mpd
# - 缓存数据: ~/.cache/{app}
# - 配置文件: ~/.config/{app}
# ========================================================================

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
let
  # ===== 统一路径定义 (集中管理) =====
  paths = {
    musicDir    = "${config.home.homeDirectory}/Music";         # 主音乐库目录
  };
in
{
  # ===== 目录初始化 =====
  home.activation.ensureMusicDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # 创建音乐库目录
    mkdir -p "${paths.musicDir}"
  '';

  # ===== XDG 用户目录规范 =====
  xdg.userDirs = {
    enable = true;
    music = paths.musicDir;  # 标准化音乐目录位置
  };

  # ===== 实用工具包 =====
  home.packages = with pkgs; [
    pulsemixer       # 终端音量控制 (pulsemixer)
    pavucontrol      # pulseaudio 高级控制面板
    alsa-utils       # alsa 底层工具 (alsamixer/amixer)
    yt-dlp           # 音频下载工具 (yt-dlp -x --audio-format mp3 url)
  ];

  imports = [
    ./easyeffects.nix
    ./lx-music.nix
    ./mpd.nix
    ./playerctld.nix
    ./spotify.nix
  ];


}


