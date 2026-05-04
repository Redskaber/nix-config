# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/just.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::just
# - Handy way to save and run project-specific commands


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    just
  ];

}


