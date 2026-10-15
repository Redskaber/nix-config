# @path: ~/projects/configs/nix-config/lib/shared/faces.nix
# @author: redskaber
# @datetime: 2026-10-15
# @description: lib::shared::faces — flake-protocol face assembler
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
#
# The LINKER of the pipeline. The backend passes hand over finished
# artifacts — targets.nix emits closures, tests/default.nix emits the
# test matrix, docs.nix emits the options reference — and THIS file is
# the one place that assembles them onto flake-protocol output names.
# flake.nix is left with exactly two responsibilities: INPUT
# registration (the input bookkeeping comments live there, next to
# each pin) and ONE line of delegation:
#
#   outputs = { self, ... }@inputs:
#     import ./lib/shared/faces.nix { inherit self inputs; };
#
# Nothing between "a producer exists" and "the flake protocol exposes
# it" happens at the entry layer — every former piece of assembly
# content lives producer-side now (toplevel projections in targets.nix;
# the gates / pdsh / tests imports below).
#
# Layer map (compiler three-stage mirroring, linker explicit at the
# protocol boundary):
#
#   lib/shared/lang/          front-end — types, enums, schema
#   lib/shared/runtime/       IR synthesis — policy data → handle
#   lib/shared/targets.nix    codegen — inventory → closures
#   lib/shared/docs.nix       side-channel emit — options reference
#   lib/shared/faces.nix      link — artifacts → protocol names
#   flake.nix                 registration + delegation, nothing else
{
  self,
  inputs,
  ...
}:
let
  # ── The backend pass, instantiated ONCE ──────────────────────
  # The argument record the deploy census test (tests/lib/shared/
  # deploy.nix) imports verbatim: the pinned channels and the full
  # input set — one targets evaluation feeds every closure face
  # below AND the api surfaces.
  targets = import ./targets.nix {
    inherit self;
    inherit (inputs) nixpkgs nixpkgs-unstable;
    inherit inputs;
  };

  # The pipeline's base policy IR handle — everything flake-level
  # reads THIS instead of re-importing lib/shared (the backend pass
  # already exports the base instance it built; see targets.nix).
  shared = targets.base;
  pkgs = shared.pkgs;
  devDir = shared.devDir;

  # ── devShells loader, hoisted ONCE ───────────────────────────
  # tests/docs-ssot.nix counts `builtins.attrNames pdsh` against the
  # README quick-ref — the SAME attrset the devShells output below
  # exposes. One construction, two consumers (the argument record is
  # the pdshell loader's own contract, tests/lib/shared/pdshell.nix
  # asserts it verbatim).
  pdsh = shared.pdshells {
    inherit
      pkgs
      inputs
      shared
      devDir
      ;
  };

  # ── Test matrix, imported ONCE ──────────────────────────────
  # Two faces over the same member thunks: the flat `checks` attrset
  # (one derivation per attr, exactly what `nix flake check`
  # expects) and the `planes` groups (the taxonomy's own grouping,
  # exposed via api.checks.planes so CI hands a whole plane to
  # nix-fast-build). One import = one evaluation.
  tests = import ../../tests { inherit inputs shared; };
in
{
  # ── api — the operator/CI surfaces ────────────────────────────
  api.inputs = inputs;
  api.shared = shared;
  api.targets = targets.inventory;
  # The planes face of the test matrix.
  # `nix-fast-build --flake .#api.checks.planes.<plane>` is the CI
  # handoff point — the fragment resolves to an attrset of
  # derivations with the SAME shape as .#checks.${system}.
  api.checks.planes = tests.planes;

  # The host-closure build face — the Linux system toplevels,
  # data-driven from the inventory (a new NixOS host joins by
  # construction). CI hands this whole face to nix-fast-build for
  # closure-level build depth; produced by targets.nix alongside its
  # sibling formats.
  api.host-toplevels = targets.hostToplevels;

  # The darwin build face — same inventory discipline (a second
  # darwin host joins by construction, zero CI-side edits); the
  # members are the nix-darwin toplevels (what `darwin-rebuild`
  # builds). Consumed by CI's darwin leg on a macos-latest (aarch64)
  # runner; evaluation stays system-independent.
  api.darwin-toplevels = targets.darwinToplevels;

  # ── debug — `nix eval .#debug.<name>` ─────────────────────────
  debug.test_system = pkgs.stdenv.hostPlatform.system;
  debug.test_devDir = devDir;

  # ── checks — the flat face `nix flake check` requires ─────────
  # Test planes 0–5 + the six repo-hygiene gates: the pre-commit
  # eval gate (tests/pre-commit.nix), the docs-SSOT contract
  # (tests/docs-ssot.nix — README/test-matrix count anchors asserted
  # against live facts at BUILD time, which is why CI STAGE 1 builds
  # both), the testScript syntax gate (tests/testscript-syntax.nix —
  # python-compiles every composed testScript at the cheapest
  # possible layer), the module-reachability gate
  # (tests/module-reachability.nix — every module dir under home/ +
  # platform/ must be reachable from the flake's evaluated faces), the
  # platform-grammar gate (tests/platform-grammar.nix — the
  # tree-shape layer of the same ledger), and the cache-identity
  # drift gate (tests/cache-ssot.nix — the fleet binary-cache
  # identity single-sourced in lib/shared/lang/const.nix; the
  # by-value consumers are the host sides (nixos · darwin), every
  # plane that cannot evaluate the const — the CI workflows, just,
  # the guide prose — carries a literal mirror pinned to it, and
  # the flake itself carries no cache identity at all (nixConfig
  # deliberately absent, round 27 — the gate asserts the entry
  # layer's silence). The FLAT face only —
  # `nix flake check` requires each attribute here to be a
  # derivation, so the planes grouping lives behind api.checks.planes,
  # never inside this output. The docs-SSOT gate is deliberately NOT
  # inside tests.planes: it counts them, so membership would be
  # circular — the composition keeps the counted set and the counter
  # in separate thunks.
  checks.${shared.arch.tag} =
    tests.checks
    // (import ../../tests/pre-commit.nix {
      inherit
        inputs
        self
        shared
        ;
    })
    // (import ../../tests/docs-ssot.nix {
      inherit
        inputs
        self
        shared
        tests
        ;
      inventory = targets.inventory;
      devShellNames = builtins.attrNames pdsh;
    })
    // (import ../../tests/testscript-syntax.nix {
      inherit
        inputs
        self
        shared
        ;
    })
    // (import ../../tests/module-reachability.nix {
      inherit
        inputs
        self
        shared
        ;
    })
    // (import ../../tests/platform-grammar.nix {
      inherit
        inputs
        self
        shared
        ;
    })
    // (import ../../tests/cache-ssot.nix {
      inherit
        self
        shared
        ;
    });

  # ── packages — 'nix build', 'nix shell', etc ──────────────────
  packages.${shared.arch.tag} = shared.packages // {
    # Options reference for the export/ modules — the doc factory is
    # producer-side (lib/shared/docs.nix, the side-channel emit
    # pass); this is the protocol-name mapping only.
    module-docs = import ./docs.nix {
      inherit
        self
        inputs
        ;
      nixpkgs = inputs.nixpkgs;
      arch = shared.arch.tag;
    };
  };

  # ── overlays — packages and patches as overlays ────────────────
  overlays = shared.overlays;

  # ── formatter — `nix fmt` ──────────────────────────────────────
  formatter.${shared.arch.tag} = pkgs.nixfmt;

  # ── reusable modules — standard flake output names ───────────
  # These are usually stuff you would upstream into nixpkgs /
  # home-manager.
  nixosModules = import ../../export/nixos;
  homeModules = import ../../export/home;
  # Legacy aliases kept for existing consumers.
  nixos = import ../../export/nixos;
  home = import ../../export/home;

  # ── devShells — the pdsh construction lives in the let above, ──
  # hoisted once so the docs-SSOT check counts the same attrset the
  # output exposes
  devShells.${shared.arch.tag} = pdsh;

  # ── Host closures — HOST-KEYED, CAPABILITY-ROUTED, PRODUCED by
  # lib/shared/targets.nix ────────────────────────────────────────
  # 'sudo nixos-rebuild --flake <flake_path>#<host> switch'
  # Hosts are enumerated from hosts/ automatically; the legacy
  # username-platform alias keeps the old attr reachable.
  inherit (targets) nixosConfigurations;
  # Standalone home-manager entrypoints — per host:
  # '<user>@<host>'; available through 'home-manager --flake
  # .#<user>@<host>'.
  inherit (targets) homeConfigurations;
  # nix-darwin entrypoints: hosts/<h> whose policy declares
  # platform.tag = "darwin" are built through nix-darwin;
  # 'darwin-rebuild switch --flake .#<host>'.
  inherit (targets) darwinConfigurations;
  # Deployment face: the colmenaHive output colmena 0.5+ reads —
  # produced by targets.nix like every other closure format;
  # 'just deploy <host>' → colmena apply --on <host>.
  inherit (targets) colmenaHive;
}
