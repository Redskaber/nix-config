# @path: ~/projects/configs/nix-config/src/core/app/google-chrome.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/src/options.xhtml#opt-programs.google-chrome.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.google-chrome
  ];

}

