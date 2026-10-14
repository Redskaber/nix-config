# @path: ~/projects/configs/nix-config/platform/nixos/home/default.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: platform::nixos::home — the NixOS home door (grammar v4)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# THE home door of platform/nixos — entry and dispatch for the user
# domain (directory grammar v4, platform-major, domain-explicit):
# mkHomeSystem imports platform/<tag>/home and lands here. The door
# IS the HM payload module: the HM base facts, the cross-platform
# user library imports, and nothing else — the platform-specific
# user content stays in this subtree, the shared content in the
# repo-root library the imports below reach.
#
# The arch axis is NOT modelled: v3's per-arch payload rows
# (home/<arch>.nix) are retired — every arch of the platform walks
# this ONE pipeline, and arch differences are absorbed at the
# nixpkgs layer (the emitter reads the per-host pkgs handle that
# runtime.nix synthesizes with { system = arch.tag; }). This is
# your home-manager configuration file — it replaces
# ~/.config/nixpkgs/home.nix.
#
# nixos hosts keep BOTH doors live on purpose — a policy, not a
# residue: the standalone HM closure switches in seconds and rolls
# back independently of the system generation, while the system
# door at ../system owns hardware/services. The two option
# universes never share a FILE (that would need option-existence
# sniffing — config-layer if-else, forbidden) and never share a
# DOOR.
{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
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
