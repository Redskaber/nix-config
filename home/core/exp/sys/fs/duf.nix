# @path: ~/projects/configs/nix-config/home/core/exp/sys/fs/duf.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::sys::duf
# - terminal data json ser

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [
    duf
  ];

}
