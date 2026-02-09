# @path: ~/projects/configs/nix-config/home/core/app/mpv.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.mpv.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [
    mpv
  ];

  # Used user config:
  xdg.configFile."mpv" = {
    source = inputs.mpv-config;     # abs path
    recursive = true;               # rec-link
    force = true;
  };

}



