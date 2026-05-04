# @path: ~/projects/configs/nix-config/home/core/app/music/mpd.nix
# @author: redskaber
# @datetime: 2026-02-14
# @description: home::core::app::music::mpd

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
    mpdData     = "${config.xdg.dataHome}/mpd";                 # MPD 核心数据
    playlists   = "${config.xdg.dataHome}/mpd/playlists";       # 播放列表存储
    tagCache    = "${config.xdg.dataHome}/mpd/tag_cache";       # 音乐数据库
    lyrics      = "${config.xdg.dataHome}/lyrics";              # 歌词存储
    visualizerFifo = "/tmp/mpd.fifo";                           # 音频可视化管道
  };
in
{
  # ===== 目录初始化 =====
  home.activation.ensureMpdDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # 创建 MPD 核心目录
    mkdir -p "${paths.mpdData}"
    mkdir -p "${paths.playlists}"
    mkdir -p "${paths.lyrics}"
  '';

  # ===== 实用工具包 =====
  home.packages = with pkgs; [
    mpc              # mpd 命令行控制器 (mpc play/pause/next)
  ];

  # ===== MPD 服务配置 (音乐播放核心) =====
  services.mpd = {
    enable = true;
    musicDirectory = paths.musicDir;       # 音乐文件根目录
    dataDir = paths.mpdData;               # 服务数据存储
    playlistDirectory = paths.playlists;   # 播放列表位置
    dbFile = paths.tagCache;               # 音乐数据库文件
    network = {
      listenAddress = "127.0.0.1";         # 仅本地访问 (安全)
      port = 6600;                         # 标准 MPD 端口
    };
    # 音频输出配置
    extraConfig = ''
      # 主音频输出 (PulseAudio)
      audio_output {
        type "pulse"
        name "PulseAudio Output"
        mixer_type "software"
      }

      # 为 ncmpcpp 可视化创建 FIFO 管道
      audio_output {
        type "fifo"
        name "my_visualizer"
        path "${paths.visualizerFifo}"
        format "44100:16:2"
      }
    '';
  };
  # ===== 环境变量 (客户端连接配置) =====
  home.sessionVariables = {
    MPD_HOST = "127.0.0.1";  # MPD 服务地址
    MPD_PORT = "6600";       # MPD 服务端口
  };

  # ===== ncmpcpp 配置 (MPD 终端客户端) =====
  programs.ncmpcpp = {
    enable = true;
    package = pkgs.ncmpcpp.override {
      visualizerSupport = true;  # 启用音频可视化
      clockSupport = true;       # 启用时钟显示
    };
    mpdMusicDir = paths.musicDir;  # 音乐目录同步
    # 智能按键绑定 (Vim 风格)
    bindings = [
      { key = "j"; command = "scroll_down"; }
      { key = "k"; command = "scroll_up"; }
      { key = "J"; command = [ "select_item" "scroll_down" ]; }
      { key = "K"; command = [ "select_item" "scroll_up" ]; }
      { key = "."; command = "seek_forward"; }
      { key = ","; command = "seek_backward"; }
    ];
    # 增强 UI 体验
    settings = {
      # 基础界面
      user_interface = "alternative";
      song_list_format = "$7($4%l$9$7) $2%t$9 $8by$9 $6%a$9";
      playlist_display_mode = "columns";

      # 显示增强
      display_bitrate = "yes";
      display_remaining_time = "no";

      # 状态栏
      statusbar_visibility = "yes";
      progressbar_look = "=>";  # 进度条样式

      # 颜色方案 (Catppuccin 风格)
      colors_enabled = "yes";
      playlist_disable_highlight_delay = "0";
      volume_color = "cyan";

      # 音频可视化
      visualizer_output_name = "my_visualizer";
      visualizer_in_stereo = "yes";
      visualizer_type = "spectrum";       # 可选: spectrum/ellipse/wave
      visualizer_look = "*|";             # 光谱块样式
      visualizer_color = "176";           # 颜色代码 (淡紫)
      "visualizer.framerate" = 30;        # 30 FPS 流畅动画
      "visualizer.autoscale" = "yes";     # 自动缩放幅度

      # 歌词管理
      lyrics_directory = paths.lyrics;   # 集中存储位置
    };
  };
  # ===== 歌词目录初始化 =====
  home.file."${paths.lyrics}".source = pkgs.runCommand "empty-lyrics-dir" {
    preferLocalBuild = true;
  } "mkdir -p $out";


}


