# @path: ~/projects/configs/nix-config/lib/shared/runtime/default.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: lib::shared::runtime::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
#
# Phase 2 of the two-phase shared initialisation.
# Merges schema+enum (phase 1) with user_shared (shared.nix values) and
# injects runtime-only fields that require pkgs or inputs:
#
#   pkgs        — stable nixpkgs instance (with user overlays + config)
#   upkgs       — unstable nixpkgs instance (allowUnfree only)
#   isNixOS     — bool: platform == nixos (used for conditional module loading)
#   homeDir     — string: platform-aware home directory path
#   orc         — configuration-orchestrator lib (wallust theme injection)
#   _user_shared — snapshot of raw user_shared before merge (debug/introspection)
#
# Merge order: shared (schema+enum) ← user_shared ← runtime fields
# Later keys win; runtime fields always override any same-named user_shared key.

{ shared
, user_shared
, nixpkgs
, nixpkgs-unstable
, inputs
, ...
}:
let
  isNixOS     = shared.fn.isNixOS user_shared.platform;                               # bool
  sopsFile    = shared.fn.sopsFile shared.self shared.const.secrets.chipr;            # fn
  sopsPath    = shared.fn.sopsRuntimePath shared.const.secrets.runtimePath;           # fn
  sopsUserPath= shared.fn.sopsRuntimePath shared.const.secrets.forUsersPath;          # fn
  homeDir     = shared.fn.homeDir user_shared.platform user_shared.user.username;     # const
  pattrs      = if user_shared ? nixpkgs
                then { system = user_shared.arch.tag; } // user_shared.nixpkgs
                else { system = user_shared.arch.tag; };
  pkgs        = import nixpkgs pattrs;                                                # obj
  upkgs       = import nixpkgs-unstable pattrs;                                       # obj
  orc         = inputs.configuration-orchestrator.lib.${user_shared.arch.tag};        # obj

  runtime_shared = shared // user_shared // {
    inherit
      homeDir
      pkgs upkgs orc
      isNixOS
      sopsFile sopsPath sopsUserPath;
    _user_shared = user_shared;
  };

in runtime_shared
