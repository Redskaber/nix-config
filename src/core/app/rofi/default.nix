# @path: ~/projects/configs/nix-config/src/core/app/rofi/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @directory: https://nix-community.github.io/home-manager/options.xhtml


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [ rofi ];

  xdg.configFile."rofi/theme.rasi".source = ./dotconfig/theme.rasi;
  xdg.configFile."rofi/config.rasi".source = ./dotconfig/config.rasi;

  xdg.configFile."rofi/powermenu-theme.rasi".source = ./dotconfig/powermenu-theme.rasi;
}


