# @path: ~/projects/configs/nix-config/home/hosts/linux/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::hosts::linux::default
# @diractory: https://nix-community.github.io/home-manager/options.xhtml


# This is your home-manager configuration file
# Use this to configure your home environment (it replace ~/.config/nixpkgs/home.nix)
{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./${shared.arch.second}.nix
  ];


}


