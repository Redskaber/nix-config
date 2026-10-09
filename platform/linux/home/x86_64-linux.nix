# @path: ~/projects/configs/nix-config/platform/linux/home/x86_64-linux.nix
# @author: redskaber
# @datetime: 2026-03-07
# @description: platform::linux::home::x86_64-linux — HM payload row (T5.11)
# @directory: https://nix-community.github.io/home-manager/options.xhtml

# The x86_64-linux arch row of platform/linux' user domain (grammar
# v3: arch rows live INSIDE home/ — see platform/nixos/home/
# x86_64-linux.nix for the full row contract). This is your
# home-manager configuration file — it replaces
# ~/.config/nixpkgs/home.nix.
{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  # linux non-nixos environment inject
  targets.genericLinux = {
    enable = true;
    nixGL = {
      packages = inputs.nixgl.packages;
      defaultWrapper = "mesa";
      offloadWrapper = "mesaPrime";
    };
  };

  home = {
    username = shared.user.username;
    homeDirectory = shared.homeDir;
    stateVersion = shared.version.value.stateVersion;
  };
  programs.home-manager.enable = true;

  # You can import other home-manager modules here
  imports = [
    # If you import other home-manager modules from other flakes (such as nix-colors):
    # You can also split up your configuration and import pieces of it here:
    ../../../home/core
    ../../../home/env
    ../../../home/wm
    # devShells: import dev/lang.nix from flake.nix
  ];

  # used user custom inxpkgs
  nixpkgs = shared.nixpkgs;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

}
