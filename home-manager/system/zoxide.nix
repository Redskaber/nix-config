# @path: ~/projects/nix-config/home-manager/system/zoxide.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zoxide.enable


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


