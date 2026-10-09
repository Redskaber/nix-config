# @path: ~/projects/configs/nix-config/platform/darwin/home/aarch64-darwin.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: platform::darwin::home::aarch64-darwin — Apple Silicon HM payload row (T3.2/T5.11)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# The aarch64-darwin arch row of platform/darwin' user domain (grammar
# v3, directory-as-domain, T5.11). Mounted by the platform customs
# (../default.nix — the darwin system router since the T5.8 fold)
# under home-manager.users.<user> as
# `import ./home/${shared.arch.tag}.nix` — the cross-domain reference
# is now EXPLICIT in the path: the system door reaches INTO the user
# subtree, and you can see it do so. Activation rides the darwin-rebuild
# path — one system activation, no standalone home-manager switch.
# There is no home/default.nix next to this row: the standalone door
# is closed on darwin by dispatch policy (standaloneHosts =
# !caps.darwin), by structure (default.nix is a system module) and by
# grammar (no home/default.nix in this subtree, T5.11); an Intel Mac
# grows an ./x86_64-darwin.nix sibling.
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
