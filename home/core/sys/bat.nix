# @path: ~/projects/configs/nix-config/home/core/sys/bat.nix
# @author: redskaber
# @datetime: 2026-01-10
# @description: Atuin — Magical shell history with sync, search & stats


{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.bat = {
    enable = true;
    config = {
      pager = "less -CN";
      theme = "gruvbox-dark";
    };
    extraPackages = with pkgs.bat-extras; [
      batman
      batpipe
      # batgrep
      # batdiff
    ];
  };

}


