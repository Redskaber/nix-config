# @path: ~/projects/configs/nix-config/home/core/app/nh.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.nh.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  programs.nh = {
    enable = true;
    clean = {
      enable = false;
      extraArgs = "--keep-since 7d --keep 5";
    };
    flake = "/home/$USER/projects/configs/nix-config";
  };

  home.packages = with pkgs; [
    nix-output-monitor
    nvd
  ];
}


