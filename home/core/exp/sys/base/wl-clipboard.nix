# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/wl-clipboard.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::wl-clipboard


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [
    wl-clipboard    # command-line
  ];
}


