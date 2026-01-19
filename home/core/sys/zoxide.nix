# @path: ~/projects/configs/nix-config/home/core/sys/zoxide.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::sys::zoxide
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.zoxide.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    # options: extra params
    # options = [ "--no-cmd" ];
  };
}


