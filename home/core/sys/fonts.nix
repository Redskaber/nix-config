# @path: ~/projects/configs/nix-config/home/core/sys/fonts.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::sys::fonts
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.fonts.enable


{ inputs
, config
, lib
, pkgs
, ...
}:
{

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts-color-emoji
    # chinese
    noto-fonts-cjk-sans
  ];

  # fonts:
  # enable -> ~/.local/share/fonts/*
  fonts = {
    fontconfig.enable = true;
    fontconfig.defaultFonts.monospace = [ "JetBrainsMono Nerd Font" ];
    fontconfig.defaultFonts.emoji = [ "Noto Color Emoji" ];
  };
}


