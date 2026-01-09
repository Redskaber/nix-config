# @path: ~/projects/configs/nix-config/home-manager/system/direnv.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.direnv.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    # enableFishIntegration = true;
    # config = {};
    nix-direnv.enable = true;
    # stdlib = "# Managed by Home Manager - enables nix-direnv";
  };
}


