# @path: ~/projects/configs/nix-config/hosts/darwin/default.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: hosts::darwin — darwin machine profile (T3.2)
#
# Eval-level darwin machine (the T2.5 pattern applied to darwin): this
# host proves the flake evaluates a full nix-darwin + home-manager
# closure from its own policy file (hosts/darwin/shared.nix). The toplevel
# is built under aarch64-darwin; activation itself needs a real Mac
# (darwin-rebuild switch --flake .#darwin) — evaluation depth is the
# acceptance this sandbox can honestly provide.

{ shared, ... }:

{
  # Apple Silicon.
  nixpkgs.hostPlatform = shared.arch.tag;

  # Registered user (created manually on the machine; declared here so
  # the closure knows its shape).
  users.users."${shared.user.username}" = {
    name = shared.user.username;
    home = shared.homeDir;
  };

  # Minimal, non-invasive system posture: leave most Aqua defaults to
  # the user; this file exists to make the closure evaluable and true.
  system.stateVersion = 6;
}
