# @path: ~/projects/configs/nix-config/src/core/system/zoxide.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/src/options.xhtml#opt-programs.zoxide.enable


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


