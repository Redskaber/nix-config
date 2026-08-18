# @path: ~/projects/configs/nix-config/nixos/wm/hyprland/plugins/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::wm::hyprland::plugins::default
#
# Design: uses shared.tools.nix-types match on shared.version for exhaustiveness.
# Adding a new version variant forces explicit handling here (no silent else).

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = (shared.tools.nix-types.match shared.version) {
    v25_11 = _: [ ./hyprscrolling.nix ];
    v26_05 = _: [ ];
  };
}
