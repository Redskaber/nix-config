# @path: ~/projects/configs/nix-config/lib/shared/default.nix
# @author: redskaber
# @datetime: 2026-03-06
# @description: lib::shared::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - shared configurations loader design
#
# Layer naming (T5.2, compiler three-stage mirroring):
#
#   lib/shared/lang/     language front-end — types, enums, schema,
#                        constants, validators (no pkgs)
#   lib/shared/runtime/  IR synthesis — policy data becomes a live
#                        handle (pkgs/overlays/sops bindings)
#   lib/shared/targets.nix  code generation — host inventory to
#                        closures
#
# This loader is the driver that threads them together.
#
# Host-scoped policy (T2.3 — the scfpath last mile):
#
#   base policy (scfpath, default ./../../shared.nix)
#     └─ hosts/<host>/shared.nix   (optional override layer)
#
#   `hostName` selects which host's override file is loaded; when null
#   the base policy's own hostName decides (the default host). Overrides
#   replace top-level keys WHOLESALE (`//`, shallow) — enum instances are
#   attrsets, so a recursive merge would corrupt their strategy payloads.
#   The merged result is re-validated through `shared.schema.shared`,
#   and `hostName` is force-aligned to the directory actually loaded:
#   the nixos tree routes hardware via `../hosts/${shared.hostName}`, so
#   loading hosts/foo/shared.nix while keeping hostName=bar would
#   silently attach the wrong machine profile.

{
  self,
  nixpkgs,
  nixpkgs-unstable,
  inputs,
  scfpath ? ../../shared.nix,
  hostName ? null,
  ...
}:
let
  # Phase 1: language front-end (types/enum/schema/validate — no pkgs).
  # The logical name `shared` is the stable wire protocol every policy
  # file and module tree speaks; the directory name says what the layer
  # IS (the configuration language), the binding says what it provides
  # (the shared contract).
  shared = import ./lang { inherit self inputs; };
  base_shared = import scfpath { inherit shared inputs; };

  # Which host are we building for?
  effectiveHost = if hostName != null then hostName else base_shared.hostName;

  # Optional per-host policy overrides: hosts/<host>/shared.nix
  hostFile = ../../hosts + ("/" + effectiveHost + "/shared.nix");
  host_overrides =
    if builtins.pathExists hostFile then import hostFile { inherit shared inputs; } else { };

  # Shallow override + forced hostName alignment + schema re-validation:
  # everything downstream of this loader still satisfies the shared schema.
  merged_shared = shared.schema.shared (
    base_shared // host_overrides // { hostName = effectiveHost; }
  );

  runtime_shared = import ./runtime {
    inherit
      shared
      nixpkgs
      nixpkgs-unstable
      inputs
      ;
    user_shared = merged_shared;
  };
in
runtime_shared
