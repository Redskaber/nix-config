# @path: ~/projects/configs/nix-config/home/core/sys/compat.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: home::core::sys::compat
# - appimage-run: used run appimage

{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [ appimage-run ];

}



