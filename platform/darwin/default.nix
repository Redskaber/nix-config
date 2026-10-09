# @path: ~/projects/configs/nix-config/platform/darwin/default.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: platform::darwin::default — darwin HM entry (T3.2)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# darwin Home Manager entry point. Consumed through nix-darwin's
# home-manager module (flake.nix darwinConfigurations → darwin/default.nix
# → home-manager.users.<user> = this file), so activation rides the
# darwin-rebuild path — one system activation, no standalone
# home-manager switch.
#
# wm routing (T3.1/T3.2): imported unconditionally, dispatched by the
# window-manager strategy — which hosts/darwin declares as "none" (Null
# Object). The darwin windowing stack (Aqua) is owned by the OS itself.

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
    ../../home/core
    ../../home/env
    ../../home/wm
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
