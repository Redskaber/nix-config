# @path: ~/projects/configs/nix-config/home/core/app/rustdesk.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.rbw.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  home.packages = with pkgs; [
    rustdesk
  ];
}


