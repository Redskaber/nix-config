# @path: ~/projects/configs/nix-config/home/core/app/wezterm.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.wezterm.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;  # auto (source wezterm.sh)
    enableBashIntegration = true;
    # package = config.lib.nixGL.wrap pkgs.wezterm; # non-nixos
    package = pkgs.wezterm;
  };

  # Used user config:
  xdg.configFile."wezterm" = {
    source = inputs.wezterm-config;   # abs path
    recursive = true;                 # rec-link
    force = true;
  };
}


