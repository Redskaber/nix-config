# @path: ~/projects/configs/nix-config/platform/darwin/system/default.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: platform::darwin::system — the darwin system door (T5.8 lineage, grammar v4)
# @directory: https://github.com/LnL7/nix-darwin
#
# THE system door of the darwin platform — entry and dispatch for the
# system domain (directory grammar v4, platform-major, domain-
# explicit). mkDarwinSystem imports platform/<tag>/system and lands
# here. One live door, one file (T5.8 fold):
#
#   system form    imports the home-manager darwinModule (module mode)
#                  + host facts from ../../../hosts/${hostName}; HM
#                  rides inside the system closure — one activation
#                  path, darwin-rebuild switch.
#   HM payload     home-manager.users.<user> = import ../home — the
#                  platform's user-domain door, mounted in module
#                  mode. The cross-domain reference is explicit in
#                  the path: the system door reaches INTO the home/
#                  subtree for the payload. The arch axis is GONE
#                  from the path (grammar v4: all arches walk the
#                  one pipeline; arch differences are absorbed by
#                  the emitter's `system` parameter at the nixpkgs
#                  layer) — the payload door itself is arch-free.
#
# Why darwin may fold what nixos may not — the live-door count: a
# module file evaluates in exactly ONE option universe, and a
# door's universe is decided by its LIVE traffic. darwin hosts
# never take the standalone-HM door (targets.nix: standaloneHosts =
# !caps.darwin — a darwin standalone closure would carry linux pkgs),
# so this platform has exactly ONE live door: the darwin system
# closure. One door → the user domain is mounted from here. nixos
# hosts run BOTH doors live (nixosConfigurations system closure +
# homeConfigurations standalone HM), so platform/nixos keeps two
# SYMMETRIC doors — system/ and home/ (a single dual-role file would
# need option-existence sniffing — config-layer if-else, forbidden).
#
# The dormant standalone door is structurally closed (this file is
# a darwin system module, not an HM module; the caps classifier
# never routes a darwin host through platform/<tag>/home) — and if
# the policy ever flips, the change point is targets.nix + this
# directory, nothing scattered.

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
    # home-manager, module mode (T5.5 lineage): provides the
    # home-manager.* option namespace this router assigns into;
    # imported HERE, not wired at the dispatch layer — the darwin
    # system form owns its HM integration.
    inputs.home-manager.darwinModules.home-manager

    # host-specific facts (machine profile)
    ../../../hosts/${shared.hostName}
  ];

  # ── home-manager, module mode ──────────────────────────────────────
  # One activation path: darwin-rebuild builds the system closure AND
  # runs the HM activation for the user. useGlobalPkgs is OFF on
  # purpose: the payload sets `nixpkgs = shared.nixpkgs` (overlays:
  # additions/patches — the in-tree pkgs like wslview ride that
  # overlay), which HM's global-pkgs mode forbids. With it off, HM
  # instantiates its own nixpkgs exactly like the standalone path —
  # same overlay semantics across all three entrypoint kinds.
  # extraSpecialArgs feeds the same host-scoped `shared` every other
  # platform consumes. The domain boundary lives in the line below
  # AND in the path it names: the value of users.<user> is a PURE HM
  # module (the platform's home door — the whole user domain, arch-
  # free), the assembly around it is pure darwin system config —
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
