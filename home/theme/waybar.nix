# @path: ~/projects/configs/nix-config/home/theme/waybar.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::theme::waybar
# - this file is window status-bar


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

  xdg.configFile."waybar" = {
    source = inputs.waybar-config;  # abs path
    recursive = true;               # rec-link
    force = true;
  };

}


