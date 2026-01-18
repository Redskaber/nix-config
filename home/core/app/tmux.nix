# @path: ~/projects/configs/nix-config/home/core/app/tmux.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.tmux.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  programs.tmux.enable = true;

  # Used user config:
  xdg.configFile."tmux" = {
    source = inputs.tmux-config;   # abs path
    recursive = true;              # rec-link
    force = true;
  };
}




