# @path: ~/projects/configs/nix-config/platform/darwin/system/default.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: platform::darwin::system — the darwin system door (grammar v4)
# @directory: https://github.com/LnL7/nix-darwin
#
# THE system door of the darwin platform (directory grammar v4,
# platform-major, domain-explicit): mkDarwinSystem imports
# platform/<tag>/system and lands here. One live door, one file:
# the form imports the home-manager darwinModule (module mode) +
# host facts from ../../../hosts/${hostName} + the platform's nix
# settings from ./nix, and mounts the user domain from here —
# home-manager.users.<user> = import ../home (the cross-domain
# reference is explicit in the path); HM rides inside the system
# closure, one activation path (darwin-rebuild).
# The arch axis is GONE from the path: the payload door is
# arch-free.
#
# Why darwin may fold what nixos may not — the live-door count: a
# door's universe is decided by its LIVE traffic. darwin hosts
# never take the standalone-HM door (standaloneHosts = !caps.darwin
# — a darwin standalone closure would carry linux pkgs), so this
# platform has exactly ONE live door and the user domain is
# mounted from here. nixos hosts run BOTH doors live
# (nixosConfigurations system closure + homeConfigurations
# standalone HM), so platform/nixos keeps two SYMMETRIC doors —
# system/ and home/ (a single dual-role file would need
# option-existence sniffing — config-layer if-else, forbidden).
# The dormant standalone door is structurally closed (this file is
# a darwin system module, not an HM module); if the policy ever
# flips, the change point is targets.nix + this directory.

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
    # home-manager, module mode: provides the home-manager.* option
    # namespace this router assigns into; imported HERE, not wired
    # at the dispatch layer — the darwin system form owns its HM
    # integration.
    inputs.home-manager.darwinModules.home-manager

    # host-specific facts (machine profile)
    ../../../hosts/${shared.hostName}

    # the platform's nix settings — the fleet-cache pull half,
    # composed BY VALUE from shared.const (the same SSOT composition
    # as the nixos customs' core/base/nix.nix).
    ./nix
  ];

  # ── home-manager, module mode ──────────────────────────────────────
  # One activation path: darwin-rebuild builds the system closure AND
  # runs the HM activation. useGlobalPkgs is OFF on purpose: the
  # payload sets `nixpkgs = shared.nixpkgs` (overlays:
  # additions/patches — the in-tree pkgs like wslview ride that
  # overlay), which HM's global-pkgs mode forbids; with it off, HM
  # instantiates its own nixpkgs exactly like the standalone path —
  # same overlay semantics across all three entrypoint kinds.
  # extraSpecialArgs feeds the same host-scoped `shared` every other
  # platform consumes. The domain boundary: users.<user> is a PURE HM
  # module (the platform's home door — the whole user domain,
  # arch-free), the assembly around it is pure darwin system config —
  # this file IS the customs between the two domains, and the
  # ../home path makes the crossing visible.
  home-manager = {
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs shared;
    };
    users.${shared.user.username} = import ../home;
  };
}
