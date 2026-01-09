# @path: ~/projects/nix-config/home-manager/system/fastfetch.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.fastfetch.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  programs.fastfetch = true;

  # Used user config:
  xdg.configFile."fastfetch" = {
    source = inputs.fastfetch-config;   # abs path
    recursive = true;                   # rec-link
    force = true;
  };
}


