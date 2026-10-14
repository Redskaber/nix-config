# @path: ~/projects/configs/nix-config/platform/darwin/home/default.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: platform::darwin::home — the darwin home door (T3.2/T5.8, grammar v4)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# THE home door of platform/darwin — the user-domain payload row
# (directory grammar v4, platform-major, domain-explicit). Unlike
# every sibling platform, this door has NO standalone traffic: the
# caps classifier (standaloneHosts = !caps.darwin) never routes a
# darwin host through platform/<tag>/home — a darwin standalone
# closure would carry linux pkgs. The door is mounted by the
# darwin system customs in module mode instead (import ../home in
# ../system/default.nix — the cross-domain reference is explicit
# in that path), and activation rides the darwin-rebuild path:
# one system activation, no standalone home-manager switch.
#
# The arch axis is NOT modelled: v3's aarch64-darwin row is retired
# — every arch of the platform walks this ONE pipeline (an Intel
# Mac shares this door; its arch is absorbed by the emitter's
# `system` parameter at the nixpkgs layer). The darwin-specific
# HM targets below are PLATFORM facts, not arch facts.
#
# wm routing (T3.1/T3.2): imported unconditionally, dispatched by
# the window-manager strategy — which hosts/darwin declares as
# "none" (Null Object). The darwin windowing stack (Aqua) is owned
# by the OS itself.
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

  # Darwin-specific HM targets (T3.2): stop HM from trying to manage
  # Linux session units — launchd owns the session on darwin.
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
