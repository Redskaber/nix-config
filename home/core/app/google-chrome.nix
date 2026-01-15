# @path: ~/projects/configs/nix-config/home/core/app/google-chrome.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.google-chrome.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    google-chrome
  ];

}

