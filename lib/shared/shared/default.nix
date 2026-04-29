# @path: ~/projects/configs/nix-config/lib/shared/shared/default.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: lib::shared::shared::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html

{ self
, inputs
, ...
}:
let
  const   = import ./const.nix;
  schema  = import ./schema.nix;
  fn      = import ./fn.nix;
  enum    = import ./enum.nix { inherit inputs; };

in {
  inherit
  const
  schema
  fn
  enum
  self
  ;
}


