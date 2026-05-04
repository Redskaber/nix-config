# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/wl-clip-persist.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::wl-clip-persist


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [
    wl-clip-persist
  ];
}


