# @path: ~/projects/configs/nix-config/home/theme/swaync.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::theme::swaync
# - swaynotificationcenter
# - Notification Center and Notification Daemon for wayland


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [
    swaynotificationcenter
  ];

  xdg.configFile."swaync" = {
    source = inputs.swaync-config;  # abs path
    recursive = true;               # rec-link
    force = true;
  };

}


