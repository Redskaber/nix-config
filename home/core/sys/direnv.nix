# @path: ~/projects/configs/nix-config/home/core/sys/direnv.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: home::core::sys::direnv
# - https://nix-community.github.io/home/options.xhtml#opt-programs.direnv.enable


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


