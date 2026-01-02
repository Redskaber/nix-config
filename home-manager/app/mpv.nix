# @path: ~/projects/nix-config/home-manager/app/mpv.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.mpv.enable
# @description: Full-featured mpv configuration for Nix + Home Manager on Ubuntu 24.04 (Wayland)


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  # auto checker GPU (default Intel/AMD(used VAAPI, NVIDIA))
  # -> hw-detect
  useVAAPI = true;
in {
  programs.mpv = {
    enable = true;
    package = pkgs.mpv;

    # core
    config = {
      # inputs
      vo = "gpu";
      gpu-api = "vulkan";         # auto / vulkan / opengl
      gpu-context = "wayland";  # default inspect
      drm-format-modifier = "auto";  # (optional) drm optimite
      # hw
      hwdec = if useVAAPI then "vaapi" else "no";  # NVIDIA user "cuda"
      hwdec-codecs = "h264,hevc,vp9,av1";  # normal hwdec-codecs
      # cache
      cache = "yes";
      cache-default = 100000; # 100MB
      cache-secs = 10; # mix-cache-time
      # Subtitles and audio tracks
      sub-auto = "fuzzy";         # auto-load same-name-sub
      audio-file-auto = "fuzzy";  # auto-load same-name-tracks
      sub-font = "JetBrainsMono Nerd Font";
      sub-font-size = 48;
      sub-color = "#FFFFFFFF";    # white-op
      sub-border-size = 2;
      sub-border-color = "#FF000000";
      # window-active
      autofit-larger = "85%x85%"; # max-window-persent 85%
      keep-open = "always";       # player-over-keep
      force-window = true;        # keep
      # YouTube / network-vedio-inspect (need yt-dlp)
      ytdl-format = "bestvideo[height<=?1080]+bestaudio/best";  # limited 1080p
      ytdl-raw-options = "merge-output-format=mkv";
      # audio
      audio-display = "no";
      volume = 100;
      volume-max = 130;           # allow-over 100% volume
      # other
      screenshot-directory = "~/Pictures/Screenshots";
      screenshot-format = "png";
      screenshot-high-bit-depth = true;
    };

    defaultProfiles = [ "gpu-hq" ];

    # custom-hotkey
    bindings = {
      # Mouse-wheel
      WHEEL_UP = "seek 10";
      WHEEL_DOWN = "seek -10";
      MBTN_LEFT = "cycle fullscreen";
      # Subtitles
      "j" = "add sub-delay -0.1";   # before
      "k" = "add sub-delay +0.1";   # after
      "v" = "cycle sub-visibility"; # change
      # tracks
      "b" = "cycle audio";          # change
      # Zoom
      "Alt+0" = "set window-scale 1.0";
      "Alt+plus" = "multiply window-scale 1.1";
      "Alt+minus" = "multiply window-scale 0.9";
      # screenshot
      "s" = "screenshot";
    };

    extraInput = ''
      # Quit with Esc
      ESC quit

      # Cycle video aspect ratio
      A cycle-values video-aspect "16:9" "4:3" "-1"
    '';

    scripts = with pkgs.mpvScripts; [
      mpris          # GNOME/KDE media-controller (play/stop/progress)
      sponsorblock   # jump YouTube donote (need yt-dlp)
      uosc           # UI(optional)
    ];
    scriptOpts = {
      osc = {
        scalewindowed = 1.5;      # controller-scale
        vidscale = false;
        visibility = "auto";
      };
      sponsorblock = {
        # categories = "sponsor,intro,outro";
        skip-sponsors = "true";
      };
    };
  };

  # depend (yt-dlp online-used)
  home.packages = with pkgs; [
    yt-dlp
    # ffmpeg # mpv references
  ];

}
