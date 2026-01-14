# @path: ~/projects/configs/nix-config/src/core/app/obsidian.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/src/options.xhtml#opt-programs.obsidian.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  home.packages = with pkgs; [ obsidian ];
}


