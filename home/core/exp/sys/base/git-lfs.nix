# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/git-lfs.nix
# @author: redskaber
# @datetime: 2026-10-17
# @diractory: home::core::exp::sys::base::git-lfs
# big size file upload

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [ git-lfs ];

}
