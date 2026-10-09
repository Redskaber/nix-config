# @path: ~/projects/configs/nix-config/darwin/default.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: darwin::default — nix-darwin system entry (T3.2)
# @directory: https://github.com/LnL7/nix-darwin
#
# The darwin twin of nixos/default.nix: one router file, host files
# underneath, home-manager integrated in module mode. Host facts come
# from ../hosts/${shared.hostName} — the SAME routing convention the
# nixos tree uses, so multi-host muscle memory transfers.

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    # host-specific facts (machine profile)
    ../hosts/${shared.hostName}
  ];

  # ── home-manager, module mode ──────────────────────────────────────
  # One activation path: darwin-rebuild builds the system closure AND
  # runs the HM activation for the user. useGlobalPkgs is OFF on
  # purpose: the platform tree sets `nixpkgs = shared.nixpkgs`
  # (overlays: additions/patches — the in-tree pkgs like wslview ride
  # that overlay), which HM's global-pkgs mode forbids. With it off,
  # HM instantiates its own nixpkgs exactly like the standalone path —
  # same overlay semantics across all three entrypoint kinds.
  # extraSpecialArgs feeds the same host-scoped `shared` every other
  # platform consumes.
  home-manager = {
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs shared;
    };
    users.${shared.user.username} = import ../platform/darwin;
  };
}
