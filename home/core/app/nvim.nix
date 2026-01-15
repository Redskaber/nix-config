# @path: ~/projects/configs/nix-config/home/core/app/nvim.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.neovide.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # Used user config:
  xdg.configFile."nvim" = {
    source = inputs.nvim-config;   # abs path
    recursive = true;              # rec-link
    force = true;
  };
}


