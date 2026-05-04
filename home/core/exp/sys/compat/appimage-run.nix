# @path: ~/projects/configs/nix-config/home/core/exp/sys/compat/appimage-run.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::compat::appimage-run
# - appimage-run: used run appimage

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [ appimage-run ];

}



