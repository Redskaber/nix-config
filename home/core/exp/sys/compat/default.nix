# @path: ~/projects/configs/nix-config/home/core/exp/sys/compat/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::compat::default
# - appimage-run: used run appimage

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./appimage-run.nix
  ];

}



