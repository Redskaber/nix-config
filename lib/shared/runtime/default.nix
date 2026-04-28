# @path: ~/projects/configs/nix-config/lib/shared/runtime/default.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: lib::shared::runtime::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html

{ shared
, user_shared
, nixpkgs
, nixpkgs-unstable
, inputs
, ...
}:
let
  isNixOS = user_shared.platform == shared.enum.platform.nixos;
  upkgs   = nixpkgs-unstable.legacyPackages.${user_shared.arch.tag};
  pattrs  = if user_shared ? nixpkgs
            then { system = user_shared.arch.tag; } // user_shared.nixpkgs
            else { system  = user_shared.arch.tag; };
  pkgs    = import nixpkgs pattrs;
  orc     = inputs.configuration-orchestrator.lib.${user_shared.arch.tag};
  runtime_shared = shared // user_shared //
  {
    # runtime auto dispatch
    inherit
      pkgs
      upkgs
      isNixOS
      orc
    ;
    # shared origin config
    _user_shared = user_shared;
  };

in runtime_shared


