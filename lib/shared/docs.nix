# @path: ~/projects/configs/nix-config/lib/shared/docs.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: lib::shared::docs — options reference emitter (T5.3)
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
#
# Side-channel emitter (the compiler's -fdump pass): the main IR
# pipeline (policy → targets.nix → closures) is untouched; this pass
# walks the export/ contract surface and emits the human-readable
# artifact alongside it. Same producer/consumer split as targets.nix —
# flake.nix only maps the finished product onto a package name.
#
#   front-end   export/home, export/nixos   the module contracts
#              (domain base sets)          each domain's option
#                                          namespaces (HM base set /
#                                          the full NixOS module set)
#
#   pass        evalModules                 one eval per module — the
#              (namespace filter)          ONLY thing kept is the
#                                          `redskaber.*` surface, so
#                                          the docs stay ours
#
#   emit        nixosOptionsDoc             CommonMark per module +
#              linkFarm                     an index — nix build
#                                          .#module-docs → result/
#
# Dependency routing is DATA (no if-else): the HM domain shares the
# Home-Manager base set; the NixOS domain evaluates all exports
# against the complete NixOS module set in ONE pass — every stock
# option our modules assign into is declared by construction.

{
  self,
  nixpkgs,
  inputs,
  arch ? "x86_64-linux",
  ...
}:
let
  lib = nixpkgs.lib;
  pkgs = import nixpkgs { system = arch; };

  # ── Home-Manager domain: the shared option namespace ─────────────
  # programs.* / home.* / xdg.* exist only because the HM base set
  # declares them. HM modules expect the HM-extended stdlib (lib.hm.*,
  # e.g. the activation DAG), so the extension is applied ONCE here.
  hmLib = import "${inputs.home-manager}/modules/lib/stdlib-extended.nix" pkgs.lib;
  hmBase = import "${inputs.home-manager}/modules/modules.nix" {
    inherit pkgs;
    lib = hmLib;
    check = false;
    useNixpkgsModule = false;
  };

  # ── NixOS domain: the full system eval ──────────────────────────
  # Same construction as the nixpkgs manual's options appendix: all
  # exported NixOS modules are evaluated ONCE against the complete
  # NixOS base module set, so every stock option they assign into is
  # declared by construction — zero per-module provider bookkeeping
  # to drift on nixpkgs bumps. The per-module doc split is recovered
  # from the namespace key (one `redskaber.<module>` attr per export).
  nixosEval = import "${nixpkgs}/nixos/lib/eval-config.nix" {
    system = arch;
    modules = builtins.attrValues (import "${self}/export/nixos");
  };

  # ── The pass: evaluate a module in the HM domain, keep our namespace ─
  mkHmOptionsDoc =
    modules:
    let
      evaluated = lib.evalModules {
        inherit modules;
        specialArgs = {
          inherit pkgs;
          lib = hmLib;
        };
      };
    in
    pkgs.nixosOptionsDoc {
      options = lib.filterAttrs (n: _: n == "redskaber") evaluated.options;
    };

  # ── Emit: one markdown per exported module ────────────────────────
  homeDocs = lib.mapAttrs (name: mod: mkHmOptionsDoc (hmBase ++ [ mod ])) (
    import "${self}/export/home"
  );

  nixosDocs = lib.mapAttrs (
    name: _:
    pkgs.nixosOptionsDoc {
      options.redskaber.${name} = nixosEval.options.redskaber.${name};
    }
  ) (import "${self}/export/nixos");

  # Domain-prefixed keys keep the two registries disjoint (home-fcitx5
  # vs nixos-fcitx5) — a flat namespace, one file per module.
  allDocs =
    (lib.mapAttrs' (n: v: lib.nameValuePair "home-${n}" v) homeDocs)
    // (lib.mapAttrs' (n: v: lib.nameValuePair "nixos-${n}" v) nixosDocs);

  index = pkgs.writeText "index.md" ''
    # nix-config — exported module options

    Options-first reference for the standalone modules under `export/`
    (interface standards: `docs/modules/interface-standards.md`). One
    file per module, generated from the live option declarations by
    `lib/shared/docs.nix` — regenerate with `nix build .#module-docs`.

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: _: "- [${n}](options/${n}.md)") allDocs)}
  '';
in
pkgs.linkFarm "nix-config-module-docs" (
  [
    {
      name = "index.md";
      path = index;
    }
  ]
  ++ lib.mapAttrsToList (n: v: {
    name = "options/${n}.md";
    path = v.optionsCommonMark;
  }) allDocs
)
