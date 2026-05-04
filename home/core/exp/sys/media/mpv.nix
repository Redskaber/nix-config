# @path: ~/projects/configs/nix-config/home/core/exp/sys/media/mpv.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::media::mpv
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.mpv.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [
    mpv
    yt-dlp
  ];

  # Used user config:
  xdg.configFile."mpv" = {
    source = inputs.mpv-config;     # abs path
    recursive = true;               # rec-link
    force = true;
  };

}



