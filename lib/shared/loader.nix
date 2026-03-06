# @path: ~/projects/configs/nix-config/lib/shared/loader.nix
# @author: redskaber
# @datetime: 2026-03-06
# @discription: lib::shared::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - shared configurations loader design


{ nixpkgs, scfpath, ... }:
let
  shared = import ./core.nix { inherit nixpkgs; };
in import scfpath { inherit shared; }


