# @path: ~/projects/configs/nix-config/src/core/app/swaync/default.nix
# @author: redskaber
# @datetime: 2025-12-12


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [ swaynotificationcenter ];

  xdg.configFile."swaync/style.css".source = ./dotconfig/style.css;
  xdg.configFile."swaync/config.json".source = ./dotconfig/config.json;
}


