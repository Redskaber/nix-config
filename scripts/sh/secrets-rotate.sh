#!/usr/bin/env bash
# @path: ~/projects/configs/nix-config/scripts/sh/secrets-rotate.sh
# @author: redskaber
# @datetime: 2026-10-08
# @description: sops key rotation / hierarchy migration runbook (T3.3 + lifecycle verbs)
#
# Architecture (dispatch-layer principle, mirroring a compiler pipeline):
#
#   .sops.yaml  ==  the IR + dispatch table.  creation_rules decide WHICH
#   recipients a path gets; `keys:` aliases carry the domain payload in
#   their name (user_*/host_*).  This script is a PASS over that IR:
#   it parses the rules into a tab-separated intermediate representation
#   (KEY/RULE lines) and executes them as data. Zero domain knowledge is
#   hardcoded here — change the rules, the checks follow automatically.
#
#   ┌────────────────────────────────────────────────────────────────┐
#   │ .sops.yaml ──parse──▶ IR (KEY/RULE lines) ──match──▶ recipients │
#   └────────────────────────────────────────────────────────────────┘
#
# Modes:
#   check                 — verify every secrets/**.yaml has (a) a matching
#                           creation_rule and (b) recipients equal to that
#                           rule's key group. Two drift classes: NO-RULE
#                           (path uncovered — plaintext risk) and DRIFT
#                           (blob recipients ≠ rule key group).
#   update                — re-encrypt existing blobs onto the CURRENT
#                           .sops.yaml rules (`sops updatekeys`): the
#                           migration step after add-host / key rotation.
#   rotate user age1…     — guided flow: swap the user_* key, updatekeys,
#                           revoke the old ciphertext reach.
#   rotate host age1…     — guided flow: generate a new host keypair, add it
#                           alongside, updatekeys, then remove the old one.
#
# Usage (prefer the just verbs — they wrap this script):
#   just secrets-verify                 | scripts/sh/secrets-rotate.sh check
#   just secrets-sync                   | scripts/sh/secrets-rotate.sh update
#   just key-rotate-user age1…          | scripts/sh/secrets-rotate.sh rotate user age1…
#   just key-rotate-host age1…          | scripts/sh/secrets-rotate.sh rotate host age1…
#
# Exit codes: 0 ok / 1 usage / 2 hierarchy drift or no-rule (check) / 3 tool missing

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SECRETS_DIR="$REPO_ROOT/secrets"
SOPS_CONFIG="$REPO_ROOT/.sops.yaml"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing tool: $1" >&2; exit 3; }; }
need sops
need awk

die() { echo "error: $*" >&2; exit 2; }

# ── IR: parse .sops.yaml into KEY/RULE lines ──────────────────────────────
#   KEY<TAB>alias<TAB>pubkey
#   RULE<TAB>path_regex<TAB>alias[,alias…]
# One pass, pure awk; the file structure is fixed by the bootstrap template
# and incremental verbs (keys: block, then creation_rules: block).
SOPS_IR_CACHE=""
sops_ir() {
  # NOTE: character classes are written as [ \t] (not [[:space:]]) so the
  # parser runs identically under mawk (Debian default) and gawk (CI).
  if [[ -z "$SOPS_IR_CACHE" ]]; then
    SOPS_IR_CACHE="$(
      awk '
        /^[ \t]*keys:/ { section = "keys"; next }
        /^[ \t]*creation_rules:/ { section = "rules"; next }
        section == "keys" && match($0, /&[A-Za-z0-9_-]+[ \t]+age1[0-9a-z]+/) {
          tok = substr($0, RSTART, RLENGTH)
          split(tok, p, /[ \t]+/)          # p[1]="&alias"  p[2]="age1…"
          sub(/^&/, "", p[1])
          print "KEY\t" p[1] "\t" p[2]
          next
        }
        section == "rules" && /- path_regex:/ {
          if (rule != "") print "RULE\t" rule "\t" refs
          rule = ""; refs = ""
          if (match($0, /path_regex:[ \t]*[^ \t]+/)) {
            rule = substr($0, RSTART + 11, RLENGTH - 11)
            sub(/^[ \t]+/, "", rule)   # drop the gap after the colon
          }
          next
        }
        section == "rules" && rule != "" && match($0, /\*[A-Za-z0-9_-]+[ \t]*$/) {
          # single line: mawk forbids a newline between ? and : of a ternary
          r_ = substr($0, RSTART + 1, RLENGTH - 1); refs = refs == "" ? r_ : refs "," r_
          next
        }
        END { if (rule != "") print "RULE\t" rule "\t" refs }
      ' "$SOPS_CONFIG"
    )"
  fi
  printf '%s\n' "$SOPS_IR_CACHE"
}

# alias → pubkey lookup over the IR.
pubkey_of() {
  sops_ir | awk -F'\t' -v a="$1" '$1 == "KEY" && $2 == a { print $3; exit }'
}

# rule that matches a path → "path_regex TAB alias,alias…" (sops semantics:
# FIRST matching rule wins), or nothing.
rule_for() {
  local path="$1" typ re refs
  while IFS=$'\t' read -r typ re refs; do
    [[ "$typ" == "RULE" ]] || continue
    # shellcheck disable=SC2254  # path_regex from .sops.yaml is used as an ERE
    if [[ "$path" =~ $re ]]; then
      printf '%s\t%s\n' "$re" "$refs"
      return 0
    fi
  done < <(sops_ir)
  return 1
}

# Expected recipients for a repo-relative path: expand the matched rule's
# key group aliases to pubkeys (sorted, space-separated on one line).
# Returns 1 when NO rule matches (caller reports NO-RULE).
expected_recipients() {
  local path="$1" matched re refs a
  if ! matched="$(rule_for "$path")"; then
    return 1
  fi
  re="${matched%%$'\t'*}"
  refs="${matched#*$'\t'}"
  [[ -n "${refs//[$'\t' ]/}" ]] || { printf '\n'; return 0; }
  local -a arr
  IFS=',' read -ra arr <<< "$refs"
  for a in "${arr[@]}"; do
    a="${a//[[:space:]]/}"
    [[ -n "$a" ]] && pubkey_of "$a"
  done | sort -u | tr '\n' ' '
  printf '\n'
}

# Blob metadata recipients (sorted, space-separated) — parsed from the sops
# stanza with awk so the toolchain stays minimal. Handles both stanza shapes
# ("recipient:" as list-item property and "- recipient:"); the enc blocks are
# base64 (no colons), so the `recipient:` anchor cannot false-positive.
# [ \t] instead of [[:space:]]: mawk/gawk compatibility.
blob_recipients() {
  awk '/^[ \t]*-?[ \t]*recipient:[ \t]*age1[0-9a-z]+/ {
        match($0, /age1[0-9a-z]+/); print substr($0, RSTART, RLENGTH)
      }' "$1" | sort | tr '\n' ' '
}

# ── check ─────────────────────────────────────────────────────────────
cmd_check() {
  # EMPTY lifecycle state (fresh clone, pre-bootstrap): the repo ships
  # with no .sops.yaml and no blobs — both are GENERATED by the just
  # flow (just secrets-init / just secret-set), never hand-committed.
  #   no rules + no blobs  → EMPTY, nothing to audit — pass with a notice
  #   blobs + no rules     → dispatch layer gone while ciphertext exists —
  #                          die (the only genuinely dangerous shape)
  #   rules + no blobs     → rules present, blobs not yet set — pass
  local blobs
  blobs=""
  if [[ -d "$SECRETS_DIR" ]]; then
    blobs="$(find "$SECRETS_DIR" -name '*.yaml' 2>/dev/null | sort)"
  fi
  if [[ ! -f "$SOPS_CONFIG" ]]; then
    if [[ -z "$blobs" ]]; then
      echo "check: EMPTY lifecycle state (no .sops.yaml, no blobs) — nothing to audit."
      echo "  bootstrap with: just secrets-init   (map: just secrets-guide)"
      return 0
    fi
    die "secrets/ carries blobs but .sops.yaml is missing — the dispatch layer is gone while ciphertext exists (plaintext risk); regenerate rules with 'just secrets-init' from the template, then 'just secrets-sync' to re-encrypt"
  fi
  local drift=0 f path matched re want have
  # `<<< "$blobs"` on an EMPTY string feeds ONE empty line (read succeeds
  # on the lone newline) — the loop would then run once with f="" and
  # report a phantom NO-RULE for the empty path. Guard the feed so the
  # documented "rules present, blobs not yet set → pass" state holds.
  if [[ -n "$blobs" ]]; then
    while IFS= read -r f; do
      path="${f#"$REPO_ROOT"/}"
      if ! want="$(expected_recipients "$path")"; then
        echo "NO-RULE: $path"
        echo "  not covered by any creation_rules path_regex — a yaml under"
        echo "  secrets/ with no rule is a plaintext-risk (sops would refuse it)"
        drift=1
        continue
      fi
      have="$(blob_recipients "$f")"
      if [[ "$want" != "$have" ]]; then
        matched="$(rule_for "$path")"
        echo "DRIFT: $path  (rule: ${matched%%$'\t'*})"
        echo "  rule wants : ${want:-<empty key group>}"
        echo "  blob has   : ${have:-<no sops metadata>}"
        drift=1
      fi
    done <<< "$blobs"
  fi
  if (( drift )); then
    echo
    echo "Hierarchy drift detected — run 'just secrets-sync'"
    echo "to re-encrypt the blobs onto the current .sops.yaml rules."
    exit 2
  fi
  if [[ -z "$blobs" ]]; then
    echo "check: .sops.yaml present, no blobs yet (pre-provision state) — nothing to audit."
  else
    echo "check: all secret blobs match the .sops.yaml hierarchy."
  fi
}

# ── update ────────────────────────────────────────────────────────────
cmd_update() {
  local f n=0
  while IFS= read -r f; do
    echo "updatekeys: ${f#"$REPO_ROOT"/}"
    sops updatekeys --yes "$f"
    n=$((n+1))
  done < <(find "$SECRETS_DIR" -name '*.yaml' 2>/dev/null | sort)
  if (( n == 0 )); then
    echo "update: no blobs yet (EMPTY lifecycle state) — nothing to re-encrypt."
  fi
}

# ── rotate user|host age1… ─────────────────────────────────────────────
cmd_rotate() {
  local domain="${1:-}" newkey="${2:-}"
  case "$domain" in
    user|host) ;;
    *) die "usage: $0 rotate user|host age1<public-key>" ;;
  esac
  [[ "$newkey" =~ ^age1[0-9a-z]+$ ]] || die "usage: $0 rotate $domain age1<public-key>"

  local oldpub alias
  alias="$(sops_ir | awk -F'\t' -v d="$domain" '$1 == "KEY" && $2 ~ "^"d"_" { print $2; exit }')"
  oldpub="$(sops_ir | awk -F'\t' -v d="$domain" '$1 == "KEY" && $2 ~ "^"d"_" { print $3; exit }')"
  [[ -n "$oldpub" ]] || die "no ${domain}_* key found in $SOPS_CONFIG"
  [[ "$oldpub" != "$newkey" ]] || die "new key identical to the current $domain key (${alias})"

  if [[ "$domain" == "user" ]]; then
    cat <<EOF
Rotating the USER key ($alias) — 3 steps, each one command:

1/3  Replace the key in $SOPS_CONFIG:
       keys: → change '$alias' value to the new public key:
         - &$alias $newkey
2/3  Re-encrypt every blob onto the new recipient set:
       just secrets-sync
3/3  Commit. Old ciphertexts remain readable by the OLD key in git
     history — accept that exposure or rewrite history (docs/secrets/
     rotation.md §compromise covers the tradeoff).
EOF
  else
    cat <<EOF
Rotating a HOST key — 4 steps (add-then-revoke, no unencrypted window):

1/4  Generate the new host keypair OUTSIDE the repo:
       just key-new-host <new-alias>
2/4  Register its public key alongside the old one:
       just key-add-host <new-alias> $newkey
3/4  Re-encrypt every blob onto both host keys:
       just secrets-sync
4/4  Revoke the old host key, then re-encrypt again — the old key
     dies with the second re-encrypt:
       just key-remove $alias
       just secrets-sync
EOF
  fi
}

case "${1:-}" in
  check)  cmd_check ;;
  update) cmd_update ;;
  rotate) shift; cmd_rotate "$@" ;;
  *) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
