# @path: ~/projects/configs/nix-config/tests/cache-ssot.nix
# @author: redskaber
# @datetime: 2026-10-15
# @description: tests::cache-ssot — fleet cache identity drift gate
#
# The sixth repo-hygiene gate, the docs-SSOT gate's sibling: it pins
# the fleet binary-cache identity (name / url / public key) to ONE
# source and audits every plane that cannot consume that source by
# value.
#
# WHY THIS EXISTS — the identity is declared once in
# lib/shared/lang/const.nix (shared.const.cache.fleet). Distribution
# follows each plane's capability: the planes that evaluate nix
# consume it BY VALUE — platform/nixos/system/core/base/nix.nix and
# platform/darwin/system/nix compose shared.const.cache.fleet.url/
# publicKey into the host substituter policy, which cannot drift.
# Every other plane cannot (or must not) evaluate the const and
# carries LITERAL mirrors, which rot silently (rename the cache or
# rotate the key and the workflow legs would keep speaking the old
# identity until someone notices):
#   - the CI workflows and scripts/just/cachix.just — the YAML/shell
#     planes cannot import nix at all;
#   - flake.nix's nixConfig — nix reads it WITHOUT evaluation
#     (forceTrivialValue semantics: only trivially forceable values,
#     list elements checked by type without any forcing — settings
#     that steer trusted substituters must not run arbitrary code at
#     metadata time), so a delegated/imported nixConfig is impossible
#     by design; the literal block is the only legal form and thus a
#     pinned mirror like the YAML/shell ones;
#   - docs/guides/cache.md — the prose identity humans copy from.
#
# WHAT IT DOES — evaluates the production handle (shared.const — the
# same instantiation checks.<sys> pays, never a re-import) and
# asserts:
#   mirrors   — the url/publicKey literals (and the cache name where
#               the plane speaks it: push commands, just variables)
#               are present in every mirror file
#   consumers — the raw url literal is ABSENT and the const reference
#               is present (restating the literal inside the one
#               by-value plane is the SSOT defect this gate exists
#               to catch)
#
# GATING — same shape as docs-ssot: `nix flake check --no-build` only
# evaluates this derivation; the drift assertion fires at BUILD
# time, which is why CI STAGE 1 builds it explicitly (plane-less
# checks are not selected by any nix-fast-build plane leg).
#
# ARGUMENTS stay key-level (the const value + file paths): zero
# evaluation beyond what checks.<sys> pays anyway (the
# single-instantiation discipline), and membership in tests.planes
# would be circular for the same reason docs-ssot stays outside it.

{
  self,
  shared,
  ...
}:
let
  lib = shared.pkgs.lib;
  fleet = shared.const.cache.fleet;

  # ── Mirror planes — cannot (or must not) evaluate the const; ────
  # literals ARE the contract, this gate keeps them honest.
  # fields: which identity literals the plane carries. cachix.just
  # composes its url from the name variable, so only name + key.
  mirrors = [
    {
      path = "/flake.nix";
      why = "flake metadata nixConfig (non-evaluative by design)";
      fields = [
        "url"
        "publicKey"
      ];
    }
    {
      path = "/.github/workflows/ci.yml";
      why = "CI substituter legs + push legs";
      fields = [
        "url"
        "publicKey"
        "name"
      ];
    }
    {
      path = "/.github/workflows/update-flake.yml";
      why = "update-flake substituter leg";
      fields = [
        "url"
        "publicKey"
      ];
    }
    {
      path = "/.github/workflows/cache-attic.yml";
      why = "attic substituter leg";
      fields = [
        "url"
        "publicKey"
      ];
    }
    {
      path = "/scripts/just/cachix.just";
      why = "just cache-axis variables (url composed from the name)";
      fields = [
        "name"
        "publicKey"
      ];
    }
    {
      path = "/docs/guides/cache.md";
      why = "the pull/push guide (prose identity)";
      fields = [
        "url"
        "publicKey"
      ];
    }
  ];

  # ── Consumer planes — must consume, never restate ────────────────
  consumers = [
    {
      path = "/platform/nixos/system/core/base/nix.nix";
      why = "host-side composition";
      ref = "shared.const.cache.fleet";
    }
    {
      path = "/platform/darwin/system/nix/default.nix";
      why = "darwin host-side composition";
      ref = "shared.const.cache.fleet";
    }
  ];

  fieldNeedle = {
    url = fleet.url;
    publicKey = fleet.publicKey;
    name = fleet.name;
  };

  mirrorLines = lib.concatMap (
    m: map (f: ''must_contain "${self}${m.path}" "${m.why} · ${f}" '${fieldNeedle.${f}}' '') m.fields
  ) mirrors;

  consumerLines = lib.concatMap (c: [
    ''must_not_contain "${self}${c.path}" "${c.why} · no raw url literal" '${fleet.url}' ''
    ''must_contain "${self}${c.path}" "${c.why} · const reference" "${c.ref}" ''
  ]) consumers;

  drv =
    shared.pkgs.runCommand "cache-ssot-check"
      {
        # Traceability: every audited file as a derivation input.
        audit = map (f: "${self}${f.path}") (mirrors ++ consumers);
      }
      ''
        set -u
        export LC_ALL=C

        FAILED=0

        # must_contain <file> <fact> <needle> — grep -F (literal bytes).
        must_contain() {
          if grep -qF -- "$3" "$1"; then
            echo "cache-ssot: ok    $2"
          else
            echo "cache-ssot: DRIFT $2 — $1 no longer carries:" >&2
            echo "    $3" >&2
            echo "    The identity lives in lib/shared/lang/const.nix" >&2
            echo "    (shared.const.cache.fleet); literal mirrors must" >&2
            echo "    follow it in the same commit." >&2
            FAILED=1
          fi
        }

        # must_not_contain <file> <fact> <needle> — the SSOT contract:
        # the by-value plane consumes the const, it never restates
        # the literal.
        must_not_contain() {
          if grep -qF -- "$3" "$1"; then
            echo "cache-ssot: DRIFT $2 — $1 restates the literal:" >&2
            echo "    $3" >&2
            echo "    Reference shared.const.cache.fleet instead — one" >&2
            echo "    source, no mirrors inside the by-value plane." >&2
            FAILED=1
          else
            echo "cache-ssot: ok    $2"
          fi
        }

        # The identity battery — ${toString (builtins.length (mirrorLines ++ consumerLines))}
        # assertions, generated from the live const at evaluation time.
        ${lib.concatStringsSep "\n" (mirrorLines ++ consumerLines)}

        if [ "$FAILED" -ne 0 ]; then
          echo "" >&2
          echo "cache-ssot-check FAILED: cache identity drifted from lib/shared/lang/const.nix." >&2
          exit 1
        fi

        echo "cache-ssot-check: ${toString (builtins.length mirrors)} mirror planes + ${toString (builtins.length consumers)} consumer planes agree with shared.const.cache.fleet"
        touch "$out"
      '';

in
# Wrapped in an attrset on purpose — the pre-commit.nix history note:
# returning a derivation bare from a module merged with `//` SPILLS its
# drv attrs into the output set and silently drops the member.
{
  cache-ssot-check = drv;
}
