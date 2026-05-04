# @path: ~/projects/configs/nix-config/home/core/app/editor/nvim.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.neovide.enable
# @description: home::core::app::editor::nvim

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    tree-sitter
    ast-grep
  ];

  programs.neovim = {
    enable = true;
    # package = shared.upkgs.neovim-unwrapped;
    defaultEditor = true;
    # img sup
    extraLuaPackages = ps: [ ps.magick ];
    extraPackages = [
      pkgs.imagemagick
      pkgs.ueberzugpp
    ];
  };

  # Used user config:
  xdg.configFile."nvim" = {
    source = inputs.nvim-config; # abs path
    recursive = true; # rec-link
    force = true;
  };
}
