# @path: ~/projects/configs/nix-config/platform/wsl/home/x86_64-linux.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: platform::wsl::home::x86_64-linux — WSL2 real specialisation (T3.1/T5.11/T7.1)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# The x86_64-linux arch row of platform/wsl' user domain (grammar v3:
# arch rows live INSIDE home/ — see platform/nixos/home/
# x86_64-linux.nix for the full row contract).
#
# WAS a byte-for-byte copy of platform/linux (review finding), then a
# real fork, now SLIMMED (T7.1): the WSL user-space interop —
# wslview, WSLENV, USERPROFILE, BROWSER routing — moved to the
# SHARED home tree (home/core/base/wsl.nix, gated on
# shared.caps.wsl) where every wsl-capable host reads it from one
# place. What stays here is precisely the standalone-wsl platform's
# OWN facts — the non-NixOS-Linux realities:
#
#   * genericLinux HM targets + nixGL — this platform's hosts run
#     a WSL distro whose system layer this flake does NOT own
#     (standalone home-manager only; the NixOS-WSL form with its own
#     userland is the sibling platform nixos-wsl).
#
# The wm import is unconditional (T3.1/T3.2 Null-Object pattern): the
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
