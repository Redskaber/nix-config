# @path: ~/projects/configs/nix-config/lib/shared/default.nix
# @author: redskaber
# @datetime: 2026-03-06
# @discription: lib::shared::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - shared configurations loader design

{ nixpkgs, nixpkgs-unstable, inputs, scfpath ? ../../shared.nix, ... }:
let
  schema = import ./schema.nix { inherit nixpkgs nixpkgs-unstable inputs; };
  jokerShared = import scfpath { inherit shared inputs; };

  # FIX: fix pkgs|upkgs and platfrom const
  pkgsAttrs = if jokerShared ? nixpkgs then
    { system = jokerShared.arch.tag; } // jokerShared.nixpkgs
  else
    { system = jokerShared.arch.tag; };
  core_pkgs = {
    pkgs  = import nixpkgs pkgsAttrs;
    upkgs = nixpkgs-unstable.legacyPackages.${jokerShared.arch.tag};
    isNixOS = jokerShared.platform == schema.platform.nixos;
  };
  shared = schema // core_pkgs;

  # reload
  _user_shared = import scfpath { inherit shared inputs; };
  fullShared = shared // _user_shared // { inherit _user_shared; };

in fullShared


