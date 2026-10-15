# @path: ~/projects/configs/nix-config/platform/linux/home/default.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: platform::linux::home — the generic-Linux home door (grammar v4)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# THE home door of platform/linux (directory grammar v4, platform-major,
# domain-explicit). Generic-Linux hosts run standalone HM only — no
# system form, hence NO system/ directory (file absence = capability
# declaration: no system emitter ever asks for this platform); the
# home door IS the platform's whole live surface and the HM payload
# module itself.
#
# The arch axis is NOT modelled — arch is absorbed at the nixpkgs
# layer (the emitter's per-host pkgs handle); the genericLinux
# targets + nixGL below are PLATFORM facts (a non-NixOS Linux
# userspace), not arch facts.
#
# The wm import is unconditional (Null-Object pattern): the
# window-manager strategy routes to home/wm/none on console hosts.
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

  imports = [
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
