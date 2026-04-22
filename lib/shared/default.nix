# @path: ~/projects/configs/nix-config/lib/shared/default.nix
# @author: redskaber
# @datetime: 2026-03-06
# @discription: lib::shared::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - shared configurations loader design

{ nixpkgs, nixpkgs-unstable, inputs, scfpath ? ../../shared.nix, ... }:
let
  shared        = import ./shared   { inherit inputs; };
  user_shared   = import   scfpath  { inherit shared inputs; };
  runtime_shared= import ./runtime  { inherit shared user_shared nixpkgs nixpkgs-unstable; };
in runtime_shared


