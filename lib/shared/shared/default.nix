# @path: ~/projects/configs/nix-config/lib/shared/shared/default.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: lib::shared::shared::default — Phase 1 aggregator (no pkgs)

{ self
, inputs
, ...
}:
let
  const  = import ./const.nix;
  schema = import ./schema.nix;
  enum   = import ./enum.nix { inherit inputs; };
  fn     = import ./fn.nix { inherit inputs enum const schema; };
  tools  = import ./tools.nix { inherit inputs; };
in {
  inherit
    const schema fn enum tools self
  ;
}
