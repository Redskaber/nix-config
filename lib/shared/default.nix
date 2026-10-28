# @path: ~/projects/configs/nix-config/lib/shared/default.nix
# @author: redskaber
# @datetime: 2026-03-06
# @description: lib::shared::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - shared configurations loader design
#
# Layer naming (compiler three-stage mirroring):
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
# Three-layer policy chain (fleet → role → host):
#
#   fleet  (scfpath, default ./../../shared.nix)
#            the base policy: identity, shared constants, majority
#            defaults — and the `roles` registry, the management
#            plane (one row per host).
#   └─ role (enum.nix `role` table, selected by the registry row)
#            the form layer: strategy BUNDLES — composition over
#            override. Adding a console host is one registry row,
#            not eight override keys.
#   └─ host  hosts/<host>/shared.nix (optional override layer)
#            class + hardware + specialisation. The host layer
#            WINS over any role key — pets, not cattle.
#
# The merge is CONTROLLED, not a bare stack of `//`:
#
#   · Law F (closed whitelist)  — a role row may only carry
#     strategy keys (enum.nix role-policy-keys). Identity keys
#     belong to fleet, class keys to host; a role row carrying
#     either dies HERE, at the single merge point, with the
#     offending keys named.
#   · hostName is force-aligned to the directory actually loaded:
#     the nixos tree routes hardware via ../hosts/${shared.hostName},
#     so a mismatched pair would silently attach the wrong machine
#     profile.
#   · `why` (provenance) — every key of the merged result is
#     stamped with the layer that won it ("fleet" | "role" |
#     "host" | "loader"), exposed on the handle as shared.why
#     (git-config's --show-origin, one eval away).
#
# The merged result is re-validated through `shared.schema.shared`,
# so everything downstream of this loader still satisfies the
# shared schema.

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
  # file and module tree speaks; the directory is the language, the
  # binding is the contract.
  shared = import ./lang { inherit self inputs; };
  base_shared = import scfpath { inherit shared inputs; };

  # Which host are we building for?
  effectiveHost = if hostName != null then hostName else base_shared.hostName;

  # ── The role layer (management plane: fleet registry) ──────────
  #
  # base_shared.roles.<host> is the role ASSIGNMENT; the row's
  # value is the strategy bundle. A missing registry or a missing
  # assignment both throw — a host without a role is a layering
  # bug, not a fallback case (silent inheritance is exactly the
  # bias the three-layer chain exists to remove).
  roleRow =
    if base_shared ? roles then
      if builtins.hasAttr effectiveHost base_shared.roles then
        base_shared.roles.${effectiveHost}
      else
        throw "lib/shared: host '${effectiveHost}' has no role assignment — add a row to the fleet registry (shared.nix → roles)"
    else
      throw "lib/shared: the base policy declares no fleet registry (shared.nix → roles) — every host needs a role assignment";

  # Law F — the role payload is a CLOSED key set: strategy keys
  # only (enum.nix role-policy-keys). A role row carrying identity
  # keys (user/git/…) or class keys (platform/arch) is a layering
  # violation; it dies here, at the single merge point, with the
  # offending keys named.
  rolePolicyKeys = shared.enum.role-policy-keys;
  roleStrategies = roleRow.value;
  roleLeak = builtins.filter (k: !builtins.elem k rolePolicyKeys) (builtins.attrNames roleStrategies);
  roleStrategiesChecked =
    if roleLeak != [ ] then
      throw "lib/shared: role '${roleRow.tag}' carries non-strategy keys [${toString roleLeak}] — role rows may only carry: ${toString rolePolicyKeys}"
    else
      roleStrategies;

  # ── The host layer (per-host specialisation) ───────────────────
  # Optional per-host policy overrides: hosts/<host>/shared.nix.
  hostFile = ../../hosts + ("/" + effectiveHost + "/shared.nix");
  host_overrides =
    if builtins.pathExists hostFile then import hostFile { inherit shared inputs; } else { };

  # ── The controlled merge chain ─────────────────────────────────
  # fleet ⊕ role ⊕ host — later layers win; hostName is
  # force-aligned to the directory actually loaded.
  mergedRaw =
    base_shared
    // roleStrategiesChecked
    // host_overrides
    // {
      hostName = effectiveHost;
    };

  # `why` (provenance): which layer won each key. The host layer
  # beats the role layer beats the fleet layer; the loader owns
  # hostName OUTRIGHT — the merge chain always re-stamps it with
  # the effective host (the fleet's `hostName` row is the DEFAULT
  # SELECTOR for loader-less construction, never the winning
  # value), so it reports "loader" regardless of any declaration.
  layerOf =
    key:
    if key == "hostName" then
      "loader"
    else if builtins.hasAttr key host_overrides then
      "host"
    else if builtins.hasAttr key roleStrategiesChecked then
      "role"
    else if builtins.hasAttr key base_shared then
      "fleet"
    else
      "loader";
  why = builtins.listToAttrs (
    map (k: {
      name = k;
      value = layerOf k;
    }) (builtins.attrNames mergedRaw)
  );

  # Schema re-validation: everything downstream of this loader
  # still satisfies the shared schema.
  merged_shared = shared.schema.shared mergedRaw;

  runtime_shared = import ./runtime {
    inherit
      shared
      nixpkgs
      nixpkgs-unstable
      inputs
      ;
    # `why` rides along as a sibling of the policy keys (the
    # _user_shared precedent) — the schema never sees it, the
    # handle exposes it: shared.why.window-manager == "role".
    user_shared = merged_shared // {
      inherit why;
    };
  };
in
runtime_shared
