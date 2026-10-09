# @path: ~/projects/configs/nix-config/lib/shared/runtime/default.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: lib::shared::runtime::default — Phase 2 runtime injection
#
# Phase 2 of the two-phase shared initialisation.
# Merges schema+enum+tools (phase 1) with user_shared (shared.nix values) and
# injects runtime-only fields that require pkgs or inputs.
#
# Merge order: shared (schema+enum+tools) <- user_shared <- runtime fields
# Later keys win; runtime fields always override any same-named user_shared key.

{
  shared,
  user_shared,
  nixpkgs,
  nixpkgs-unstable,
  inputs,
  ...
}:
let
  inherit (inputs.nix-types.lib) result;

  # ── T4.0: capability resolution ───────────────────────────────────
  # THE one place platform semantics get resolved for downstream passes.
  # The platform dispatch table (enum.nix) declares caps vectors; this pass
  # publishes the host's row as `shared.caps` so leaves read resolved facts
  # (shared.caps.linux-family) instead of re-deriving platform identity
  # through predicate calls or raw tag comparisons.
  caps = user_shared.platform.value.caps;

  # Dual-source scope resolution, centralised (T4.0) — dispatch as DATA
  # (T4.1, README 数据驱动 principle): the declared source string selects
  # its scope from one table; an unknown declaration fails loudly with
  # the legal surface spelled out (front-end diagnostic). The only
  # writers are the schema default ("stable") and shared.nix / hosts
  # overrides — both upstream of this pass.
  source-scopes = {
    stable = pkgs;
    unstable = upkgs;
  };
  i18nScope =
    source-scopes.${user_shared.i18n.nixpkgs-source}
      or (throw "i18n.nixpkgs-source \"${user_shared.i18n.nixpkgs-source}\" is not one of [ stable unstable ] — fix the declaration in shared.nix or hosts/<host>/shared.nix");

  # ── T4.1: Result-typed secret path boundary ─────────────────────
  # The railway lives in shared.validate (ok/err/andThen — nix-types
  # ADT): shape checks are the front end, the existence check is the
  # resolution pass, so a declared-but-missing secret dies at EVAL
  # time with its diagnostic. THIS is the single edge where a bare
  # string is required (sops module attrs take strings): unwrapOrElse
  # throw makes the Err value the eval error verbatim.
  unwrapSecret = result.unwrapOrElse throw;

  sopsFile = rel: unwrapSecret (shared.validate.sopsFileR shared.self shared.const.secrets.chipr rel);
  sopsPath =
    rel: unwrapSecret (shared.validate.sopsRuntimePathR shared.const.secrets.runtimePath rel);
  sopsUserPath =
    rel: unwrapSecret (shared.validate.sopsRuntimePathR shared.const.secrets.forUsersPath rel);
  homeDir = shared.fn.homeDir user_shared.platform user_shared.user.username;
  pattrs =
    if user_shared ? nixpkgs then
      { system = user_shared.arch.tag; } // user_shared.nixpkgs
    else
      { system = user_shared.arch.tag; };
  pkgs = import nixpkgs pattrs;
  upkgs = import nixpkgs-unstable pattrs;

  # External tool libraries — resolved at runtime (arch-specific where needed)
  # Config files access via shared.tools.<name> (short, decoupled from inputs)
  orc-lib = shared.tools.orc-raw.${user_shared.arch.tag};
  pdshell-lib = shared.tools.pdshell-raw;

  core_shared =
    shared
    // user_shared
    // {
      inherit
        homeDir
        pkgs
        upkgs
        caps
        i18nScope
        sopsFile
        sopsPath
        sopsUserPath
        ;
      _user_shared = user_shared;

      # External tools (resolved at runtime, short paths for config files)
      orc = orc-lib;
      pdshell = pdshell-lib;
      inherit (pdshell-lib) mk-pdshell pdshells;
      # tools attrset is already in shared (from phase 1), but we override
      # with resolved arch-specific orc so config files can use shared.tools.orc
      tools = shared.tools // {
        orc = orc-lib; # resolved per-arch
      };

      # ── T2.6: package-set provenance (dual-source governance) ─────
      # Fingerprints of the two nixpkgs instances this flake wires.
      # Modules assert against these via fn.sameSource to keep
      # daemon/addon style contracts single-sourced at eval time.
      provenance = {
        stable = shared.fn.pkgsFingerprint pkgs;
        unstable = shared.fn.pkgsFingerprint upkgs;
      };

      # shellIntegrations (T4.1): arrives as DATA from the shell enum
      # row — the payload table in enum.nix answers all three bits per
      # variant, exhaustively. No truth table re-derived here, no
      # `.tag == "zsh"` comparisons at this layer.
      shellIntegrations = user_shared.user.shell.value.integrations;

      # Application sets (multi-select routing): expanded from user_shared set variants
      # Config: imports = builtins.map (e: ./${e}.nix) shared.editors;
      editors = user_shared.editor-set.value.editors;
      terminals = user_shared.terminal-set.value.terminals;
      browsers = user_shared.browser-set.value.browsers;

      # Service profile (strategy carrying): expanded from user_shared variant
      # Config: enable = shared.services.db.postgresql.install;
      #         wantedBy = lib.mkForce (lib.optional shared.services.db.postgresql.autostart "multi-user.target");
      services = user_shared.service-profile.value;
    };

  runtime_shared = core_shared // {
    packages = import "${core_shared.self}/pkgs" { inherit pkgs; };
    overlays = import "${core_shared.self}/overlays" { shared = core_shared; };
  };
in
runtime_shared
