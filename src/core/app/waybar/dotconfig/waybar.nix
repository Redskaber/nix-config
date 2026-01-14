# @path: ~/projects/configs/nix-config/src/core/app/waybar/dotconfig/waybar.nix
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
  programs.waybar = {
    enable = true;
  };

}


