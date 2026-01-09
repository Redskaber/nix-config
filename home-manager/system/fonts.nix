# @path: ~/projects/configs/nix-config/home-manager/system/fonts.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.fonts.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  # fonts:
  # enable -> ~/.local/share/fonts/*
  fonts.fontconfig.enable = true;
  fonts.fontconfig.defaultFonts.monospace = [ "JetBrainsMono Nerd Font" ];
  fonts.fontconfig.defaultFonts.emoji = [ "Noto Color Emoji" ];
}


