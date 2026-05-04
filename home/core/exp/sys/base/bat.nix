# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/bat.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::bat


{ inputs
, shared
, config
, lib
, pkgs
, ...
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


