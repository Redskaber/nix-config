# @path: ~/projects/configs/nix-config/home/hosts/nixos.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::hosts::nixos
# @directory: https://nix-community.github.io/home-manager/options.xhtml


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
  home = {
    username = shared.user.username;
    homeDirectory = "/home/${shared.user.username}";
    stateVersion = shared.version;
  };
  programs.home-manager.enable = true;

  # You can import other home-manager modules here
  imports = [
    # If you import other home-manager modules from other flakes (such as nix-colors):
    # You can also split up your configuration and import pieces of it here:
    ../core
    ../wm
    # devShells: import dev/lang.nix from flake.nix
  ];

  # used user custom inxpkgs
  nixpkgs = shared.nixpkgs;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}


