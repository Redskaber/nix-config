# @path: ~/projects/nix-config/home-manager/system/starship.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.starship.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  # Used user config:
  xdg.configFile."starship" = {
    source = inputs.starship-config;  # abs path
    recursive = true;                 # rec-link
    force = true;
  };
}

