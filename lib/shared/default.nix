# @path: ~/projects/configs/nix-config/lib/shared/default.nix
# @author: redskaber
# @datetime: 2026-03-06
# @discription: lib::shared::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - shared configurations loader design


{ nixpkgs, inputs, scfpath ? ../../shared.nix, ... }:
let
  jokerShared = import ./loader.nix { inherit nixpkgs inputs scfpath; };

  core = import ./core.nix { inherit nixpkgs; };

  pkgsAttrs = if jokerShared ? nixpkgs then
    { system = jokerShared.arch.second; } // jokerShared.nixpkgs
  else
    { system = jokerShared.arch.second; };

  core_pkgs = { pkgs = import nixpkgs pkgsAttrs; };
  shared = core // core_pkgs;
  userShared = import scfpath { inherit shared inputs; };

  fullShared = shared // userShared // { _user_shared = userShared; };

in fullShared


