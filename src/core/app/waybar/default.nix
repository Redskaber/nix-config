# @path: ~/projects/configs/nix-config/src/core/app/waybar/default.nix
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
  imports = [
    ./dotconfig/waybar.nix
    ./dotconfig/settings.nix
    ./dotconfig/style.nix
  ];

}


