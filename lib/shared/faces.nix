# @path: ~/projects/configs/nix-config/lib/shared/faces.nix
# @author: redskaber
# @datetime: 2026-10-15
# @description: lib::shared::faces — flake-protocol face assembler (R31)
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
# it" happens at the entry layer anymore. Before R31 the outputs body
# still carried assembly content of its own — the host/darwin toplevel
# PROJECTIONS (listToAttrs+map over the inventory), the module-docs
# factory CALL, the five repo-hygiene gates imported and merged
# inline, the pdshells invocation, the tests import — every one of
# those is producer-side work that has since moved:
#
#   toplevel projections   → targets.nix (hostToplevels /
#                             darwinToplevels — closure formats in
#                             the emitter family, next to the
#                             colmenaHive deploy view)
#   module-docs call       → here, one import beside its siblings
#   five-gate checks merge → here, the flat `checks` face contract
#                             (nix flake check wants one derivation
#                             per attr; the planes grouping stays
#                             behind api.checks.planes, T7.3)
#   pdsh invocation        → here, hoisted ONCE (T8.1: the devShells
#                             output and the docs-SSOT counter read
#                             the same handle — one construction, two
#                             consumers, zero re-evaluation)
#   tests import           → here, imported ONCE (T7.3: one
#                             evaluation, two faces — checks + planes)
#
# Layer map (compiler three-stage mirroring, T5.2 — with the linker
# now explicit at the protocol boundary):
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
  # ── The backend pass, instantiated ONCE (T5.10) ────────────────
  # Same argument record the pre-R31 flake.nix passed (and the deploy
  # census test tests/lib/shared/deploy.nix imports verbatim): the
  # pinned channels and the full input set — one targets evaluation
  # feeds every closure face below AND the api surfaces.
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

  # ── devShells loader, hoisted ONCE (T8.1) ─────────────────────
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

  # ── Test matrix, imported ONCE (T7.3) ─────────────────────────
  # Two faces over the same member thunks: the flat `checks` attrset
  # (what the output below consumes — one derivation per attr,
  # exactly what `nix flake check` expects) and the `planes` groups
  # (the taxonomy's own grouping, exposed via api.checks.planes so CI
  # hands a whole plane to nix-fast-build). One import = one
  # evaluation; addressing a member through either face adds nothing.
  tests = import ../../tests { inherit inputs shared; };
in
{
  # ── api — the operator/CI surfaces ────────────────────────────
  api.inputs = inputs;
  api.shared = shared;
  api.targets = targets.inventory;
  # T7.3: the planes face of the test matrix.
  # `nix-fast-build --flake .#api.checks.planes.<plane>` is the CI
  # handoff point — the fragment resolves to an attrset of
  # derivations with the SAME shape as .#checks.${system}.
  api.checks.planes = tests.planes;

  # T8.2: the host-closure build face — the Linux system toplevels,
  # data-driven from the inventory (a new NixOS host joins by
  # construction). CI hands this whole face to nix-fast-build for
  # closure-level build depth; produced by targets.nix since R31
  # alongside its sibling formats.
  api.host-toplevels = targets.hostToplevels;

  # T8.3: the darwin build face — the sixth api face, same inventory
  # discipline (a second darwin host joins by construction, zero
  # CI-side edits); the members are the nix-darwin toplevels (what
  # `darwin-rebuild` builds). Consumed by CI's darwin leg on a
  # macos-latest (aarch64) runner; evaluation stays
  # system-independent.
  api.darwin-toplevels = targets.darwinToplevels;

  # ── debug — `nix eval .#debug.<name>` ─────────────────────────
  debug.test_system = pkgs.stdenv.hostPlatform.system;
  debug.test_devDir = devDir;

  # ── checks — the flat face `nix flake check` requires ─────────
  # Test planes 0–5 + the five repo-hygiene gates: the pre-commit
  # eval gate (tests/pre-commit.nix), the docs-SSOT contract
  # (tests/docs-ssot.nix, T8.1 — README/test-matrix count anchors
  # asserted against live facts at BUILD time, which is why CI STAGE
  # 1 builds both), the testScript syntax gate
  # (tests/testscript-syntax.nix, T32 — python-compiles every
  # composed testScript at the cheapest possible layer), the
  # module-reachability gate (tests/module-reachability.nix, T41 —
  # the directory side of the ledger: every module dir under home/ +
  # platform/ must be reachable from the flake's evaluated faces),
  # and the platform-grammar gate (tests/platform-grammar.nix, T46 —
  # the tree-shape layer of the same ledger).
  # The FLAT face only — `nix flake check` requires each attribute
  # here to be a derivation, so the planes grouping lives behind
  # api.checks.planes, never inside this output.
  # The docs-SSOT gate is deliberately NOT inside tests.planes: it
  # counts them, so membership would be circular — the composition
  # here keeps the counted set and the counter in separate thunks.
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
    });

  # ── packages — 'nix build', 'nix shell', etc ──────────────────
  packages.${shared.arch.tag} = shared.packages // {
    # Options reference for the export/ modules (T5.3) — the doc
    # factory is producer-side (lib/shared/docs.nix, the
    # side-channel emit pass); this is the protocol-name mapping
    # only.
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

  # ── reusable modules (T2.1) — standard flake output names ─────
  # These are usually stuff you would upstream into nixpkgs /
  # home-manager.
  nixosModules = import ../../export/nixos;
  homeModules = import ../../export/home;
  # Legacy aliases (pre-T2.1 attr names) kept for existing consumers.
  nixos = import ../../export/nixos;
  home = import ../../export/home;

  # ── devShells (T8.1: the pdsh construction lives in the let ────
  # above — hoisted once so the docs-SSOT check counts the same
  # attrset the output exposes)
  devShells.${shared.arch.tag} = pdsh;

  # ── Host closures — HOST-KEYED (T2.4), CAPABILITY-ROUTED (T4.0),
  # PRODUCED by lib/shared/targets.nix (T5.1) ────────────────────
  # 'sudo nixos-rebuild --flake <flake_path>#<host> switch'
  # Hosts are enumerated from hosts/ automatically; the legacy
  # username-platform alias keeps the pre-T2.4 attr reachable.
  inherit (targets) nixosConfigurations;
  # Standalone home-manager entrypoints — per host (T2.3):
  # '<user>@<host>'; available through 'home-manager --flake
  # .#<user>@<host>'.
  inherit (targets) homeConfigurations;
  # nix-darwin entrypoints (T3.2): hosts/<h> whose policy declares
  # platform.tag = "darwin" are built through nix-darwin;
  # 'darwin-rebuild switch --flake .#<host>'.
  inherit (targets) darwinConfigurations;
  # Deployment face (T20.1): the colmenaHive output colmena 0.5+
  # reads — produced by targets.nix like every other closure
  # format; 'just deploy <host>' → colmena apply --on <host>.
  inherit (targets) colmenaHive;
}
