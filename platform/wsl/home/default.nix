# @path: ~/projects/configs/nix-config/platform/wsl/home/default.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: platform::wsl::home — the WSL2 home door (T7.1, grammar v4)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# THE home door of platform/wsl — entry and dispatch for the user
# domain (directory grammar v4, platform-major, domain-explicit).
# WSL hosts whose distro's system layer this flake does NOT own
# run standalone HM only — no system/ directory in this platform
# (the NixOS-WSL form with its own system layer is the sibling
# platform nixos-wsl); the home door IS the platform's whole live
# surface.
#
# This door grew out of a byte-for-byte copy of platform/linux
# (a review finding), then specialised on the deltas that are
# genuinely WSL facts — genericLinux targets and nixGL are shared
# "non-NixOS Linux" facts, and the WSL user-space interop
# (wslview/WSLENV) rides in the SHARED home tree
# (home/core/base/wsl.nix, caps.wsl-gated) so every wsl-capable
# host — standalone or nixos-wsl — gets it from one place.
#
# The arch axis is NOT modelled (grammar v4): every arch of the
# platform walks this ONE pipeline. This is your home-manager
# configuration file — it replaces ~/.config/nixpkgs/home.nix.
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
