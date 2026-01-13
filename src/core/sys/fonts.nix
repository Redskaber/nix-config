# @path: ~/projects/configs/nix-config/src/core/system/fonts.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/src/options.xhtml#opt-programs.fonts.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts-color-emoji
    # chinese
    noto-fonts-cjk-sans
  ];

  # fonts:
  # enable -> ~/.local/share/fonts/*
  fonts.fontconfig.enable = true;
  fonts.fontconfig.defaultFonts.monospace = [ "JetBrainsMono Nerd Font" ];
  fonts.fontconfig.defaultFonts.emoji = [ "Noto Color Emoji" ];
}


