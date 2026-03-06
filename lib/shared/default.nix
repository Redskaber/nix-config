# @path: ~/projects/configs/nix-config/lib/shared/default.nix
# @author: redskaber
# @datetime: 2026-03-06
# @discription: lib::shared::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - shared configurations loader design


{ nixpkgs, scfpath ? ../../shared.nix, ... }:
let
  jokerShared = import ./loader.nix { inherit nixpkgs scfpath; };

  core = import ./core.nix { inherit nixpkgs; };
  core_pkgs = { pkgs = nixpkgs.legacyPackages.${jokerShared.arch.second}; };
  shared = core // core_pkgs;
  userShared = import scfpath { inherit shared; };

  fullShared = shared // userShared // { _user_shared = userShared; };

in fullShared


