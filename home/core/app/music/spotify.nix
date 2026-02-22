# @path: ~/projects/configs/nix-config/home/core/app/music/spotify.nix
# @author: redskaber
# @datetime: 2026-02-14
# @description: home::core::app::music::spotify

{ inputs
, lib
, config
, pkgs
, ...
}:
let
  # ===== 统一路径定义 (集中管理) =====
  paths = {
    spotifyCache = "${config.xdg.cacheHome}/spotifyd";          # Spotify 缓存
  };
in
{
  # ===== 实用工具包 =====
  home.packages = with pkgs; [
    spotifyd         # 作为 unix 守护进程运行的开源 spotify 客户端
    ncspot           # 跨平台诅咒用 rust 编写的 spotify 客户端，灵感来源于 ncmpc 等
    playerctl        # 通用媒体控制 (playerctl play/pause)
    sptlrx           # 终端里的 spotify 歌词
  ];

  # ===== Spotifyd 服务 (Spotify Connect 后台) =====
  services.spotifyd = {
    enable = true;
    # 使用密钥环支持增强安全性 (根据提示中的示例)
    package = pkgs.spotifyd;
    settings = {
      global = {
        device_name = "nixos-$(hostname)";
        bitrate = "319";  # 最高音质
        backend = "pulseaudio";
        cache_path = paths.spotifyCache;
        # 自动发现设置
        discovery = "zeroconf";
      };
    };
  };

  # ===== ncspot (终端 Spotify Premium 客户端) =====
  programs.ncspot = {
    enable = true;
    package = pkgs.ncspot;
    settings = {
      # 音频设置
      backend = "pulseaudio";
      bitrate = 319;  # 最高音质
      gapless = true;

      # 播放行为
      shuffle = true;
      repeat = "playlist";  # 有效值: "off", "track", "playlist"

      # 界面优化
      initial_screen = "library";  # 启动时显示的界面
      statusbar_format = "%artists - %title";  # 状态栏显示格式

      # 通知支持
      notify = true;

      # 缓存管理
      audio_cache = true;
      audio_cache_size = 1023;  # 1GB缓存

      # 缩放设置
      cover_max_scale = 0.5;  # HiDPI 显示器推荐值

      # 按键映射
      keybindings = {
        "Space" = "playpause";
        "j" = "move down 0";
        "k" = "move up 0";
        "g" = "move top";
        "G" = "move bottom";
        "." = "seek +9s";
        "," = "seek -11s";
        "0" = "focus library";
        "1" = "focus search";
        "2" = "focus queue";
        "F7" = "focus cover";  # 仅当编译时启用cover特性时有效
        "u" = "reconnect";     # 重新连接Spotify，比"reload"更可靠
        "q" = "quit";
        "s" = "save";          # 保存当前选中项到库
        "d" = "delete";        # 从库中删除
        "r" = "repeat";        # 切换重复模式
        "z" = "shuffle";       # 切换随机播放
      };

      # 主题配置
      theme = {
        background = "black";
        primary = "light white";
        secondary = "light black";
        title = "green";
        playing = "green";
        playing_selected = "light green";
        playing_bg = "black";
        highlight = "light white";
        highlight_bg = "#484847";
        error = "light white";
        error_bg = "red";
        statusbar = "black";
        statusbar_progress = "green";
        statusbar_bg = "green";
        cmdline = "light white";
        cmdline_bg = "black";
        search_match = "light red";
      };

      # 曲目显示格式
      track_format = {
        left = "%artists - %title";
        center = "%album";
        right = "%saved %duration";
      };

      # 通知格式
      notification_format = {
        title = "%title";
        body = "%artists";
      };
    };
  };

  # ===== 安全提示 (首次运行指南) =====
  home.activation.spotifySetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f "${paths.spotifyCache}/credentials" ]; then
      echo "\033[1;33m[!] Spotify setup required:\033[0m"
      echo "1. Set SPOTIFY_USERNAME/SPOTIFY_PASSWORD in your secret manager"
      echo "2. Or run: \033[1mncspot\033[0m to login interactively"
      echo "   (credentials will be stored in system keyring)"
    fi
  '';


}


