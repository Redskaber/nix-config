# @path: ~/projects/configs/nix-config/platform/linux/home/default.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: platform::linux::home — the generic-Linux home door (grammar v4)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# THE home door of platform/linux — entry and dispatch for the
# user domain (directory grammar v4, platform-major, domain-
# explicit). Generic-Linux hosts run standalone HM only — no
# system form, hence NO system/ directory in this platform (file
# absence = capability declaration: no system emitter ever asks
# for this platform); the home door IS the platform's whole live
# surface. mkHomeSystem imports platform/<tag>/home and lands
# here; the door IS the HM payload module.
#
# The arch axis is NOT modelled: v3's x86_64-linux row is retired
# — every arch of the platform walks this ONE pipeline (arch is
# absorbed at the nixpkgs layer via the emitter's per-host pkgs
# handle). The genericLinux targets + nixGL below are PLATFORM
# facts (a non-NixOS Linux userspace), not arch facts.
#
# The wm import is unconditional (T3.1/T3.2 Null-Object pattern):
# the window-manager strategy routes to home/wm/none on console
# hosts. This is your home-manager configuration file — it
# replaces ~/.config/nixpkgs/home.nix.
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
