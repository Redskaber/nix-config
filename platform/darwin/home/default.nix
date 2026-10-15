# @path: ~/projects/configs/nix-config/platform/darwin/home/default.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: platform::darwin::home — the darwin home door (grammar v4)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# THE home door of platform/darwin (grammar v4, platform-major,
# domain-explicit). No standalone traffic (standaloneHosts =
# !caps.darwin — a darwin standalone closure would carry linux
# pkgs): the darwin system customs mounts it in module mode (import
# ../home in ../system/default.nix); activation rides darwin-rebuild
# — one system activation, no standalone HM switch.
#
# The arch axis is NOT modelled — arch is absorbed by the emitter's
# `system` parameter at the nixpkgs layer; the darwin-specific HM
# targets below are PLATFORM facts, not arch facts.
#
# wm routing: imported unconditionally, dispatched by the
# window-manager strategy — hosts/darwin declares "none" (Null
# Object; the darwin windowing stack, Aqua, is OS-owned).
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

  imports = [
    ../../../home/core
    ../../../home/env
    ../../../home/wm
    # devShells: import dev/lang.nix from flake.nix
  ];

  # used user custom inxpkgs
  nixpkgs = shared.nixpkgs;

  # Darwin-specific HM targets: stop HM from trying to manage Linux
  # session units — launchd owns the session on darwin.
  targets.darwin = {
    # Don't alias default.* attrs to launchd equivalents HM knows about;
    # keeps the profile portable for eval on any builder platform.
    defaults = {
      dock.autohide = true;
      finder.FXPreferredViewStyle = "clnv";
    };
    search = "DuckDuckGo";
  };
  # sd-switch/systemd user services do not exist under launchd sessions.
  systemd.user.startServices = lib.mkForce "never";
}
