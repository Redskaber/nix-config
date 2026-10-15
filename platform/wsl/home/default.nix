# @path: ~/projects/configs/nix-config/platform/wsl/home/default.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: platform::wsl::home — the WSL2 home door (grammar v4)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# THE home door of platform/wsl (grammar v4, platform-major,
# domain-explicit). WSL hosts whose distro's system layer this
# flake does NOT own run standalone HM only — no system/ directory
# in this platform (the NixOS-WSL form with its own system layer is
# the sibling platform nixos-wsl); the home door IS the platform's
# whole live surface.
#
# genericLinux targets and nixGL are shared "non-NixOS Linux"
# facts (as in sibling platform/linux); the WSL user-space interop
# (wslview/WSLENV) rides in the SHARED home tree
# (home/core/base/wsl.nix, caps.wsl-gated) so every wsl-capable
# host — standalone or nixos-wsl — gets it from one place.
#
# The arch axis is NOT modelled (grammar v4): every arch of the
# platform walks this ONE pipeline.
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
