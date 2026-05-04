# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/cliphist.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::cliphist


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [
    cliphist
  ];
}


