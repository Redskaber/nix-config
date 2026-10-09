# @path: ~/projects/configs/nix-config/platform/darwin/default.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: platform::darwin::default — the darwin customs: system router + arch dispatch (T5.8, grammar v3 T5.11)
# @directory: https://github.com/LnL7/nix-darwin
#
# THE customs house of the darwin platform — one door, one file,
# both responsibilities (T5.8 fold), sitting at the top level = the
# system domain (grammar v3, directory-as-domain, T5.11):
#
#   system form    imports the home-manager darwinModule (module mode)
#                  + host facts from ../../hosts/${hostName}; HM rides
#                  inside the system closure — one activation path,
#                  darwin-rebuild switch.
#   arch dispatch  home-manager.users.<user> = import
#                  ./home/${shared.arch.tag}.nix — the SAME data-driven
#                  arch-row grammar every sibling user domain speaks
#                  (platform/nixos|linux|wsl /home/default.nix route
#                  identically). The cross-domain reference is
#                  explicit in the path: the system door reaches INTO
#                  the home/ subtree for the payload — v2 hid that
#                  crossing in a flat sibling filename.
#
# mkDarwinSystem imports platform/<tag> — landing in this file, the
# system customs. The platform/darwin/system/ sub-tree this file
# used to route through is GONE (T5.8 fold): its assembly lives
# here, its extra hop with it. And there is no home/default.nix
# inside platform/darwin/home/ — the standalone HM door does not
# exist on darwin (grammar v3: file absence = capability
# declaration; the arch rows still live there, mounted in module
# mode by the line below).
#
# Why darwin may fold what nixos may not — the live-door count: a
# module file evaluates in exactly ONE option universe, and
# default.nix's universe is decided by its LIVE traffic. darwin hosts
# never take the standalone-HM door (targets.nix: standaloneHosts =
# !caps.darwin — a darwin standalone closure would carry linux pkgs),
# so this platform has exactly ONE live door: the darwin system
# closure. One door → one customs file. nixos hosts run BOTH doors
# live (nixosConfigurations system closure + homeConfigurations
# standalone HM), so platform/nixos keeps two customs FILES at two
# LEVELS — default.nix at the top (system), home/default.nix one
# down (user) — a single dual-role file would need option-existence
# sniffing (config-layer if-else, forbidden). Grammar v3 (T5.11):
# directory-as-domain — the door count reads off the directory
# listing, and the domains off the levels.
#
# The dormant standalone door this directory used to keep is
# structurally closed by the fold (this file is a darwin system
# module, not an HM module) and by grammar (no home/default.nix
# under home/, T5.11). That door was never reachable — the caps
# classifier excluded it — and if the policy ever flips, the change
# point is targets.nix + this directory, nothing scattered.

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
    ../../hosts/${shared.hostName}
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
  # module (an arch row of the home/ subtree), the assembly around it
  # is pure darwin system config — default.nix IS the customs between
  # the two domains, and the ./home/… path makes the crossing visible.
  home-manager = {
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs shared;
    };
    users.${shared.user.username} = import ./home/${shared.arch.tag}.nix;
  };
}
