# ==============================================================================
# scripts/just/cachix.just
# Responsibility: the public Cachix cache axis (redskaber-nix-config) —
# status probes, the token registration flow, and local pushes.
#
# Cache topology (who pushes, who pulls):
#   PULL  every CI leg + this machine — the identity (name/url/key) is
#         single-sourced in lib/shared/lang/const.nix
#         (shared.const.cache.fleet); this module's literals are a
#         shell-plane mirror pinned to it by tests/cache-ssot.nix
#         (rename the cache or rotate the key and the gate goes red
#         until the mirrors follow). Query order is priority-driven:
#         the cache advertises 41, behind cache.nixos.org's 40, so it
#         serves only what official lacks.
#   PUSH  CI host-toplevels legs (secret.CACHIX_AUTH_TOKEN — owner verb),
#         and LOCALLY via this module (token read from the secrets
#         system — the registry/CRUD makes that a one-liner).
#
# The token is a SECRET: it lives in the sops blob tree (encrypted with
# the user's age key), never in git history, never in env files. The
# `cachix-token` verb registers + records it; `cachix-push` resolves
# CACHIX_AUTH_TOKEN env → blob, in that order.
# ==============================================================================

CACHE_NAME := "redskaber-nix-config"
CACHE_URL  := "https://" + CACHE_NAME + ".cachix.org"
CACHE_KEY  := "redskaber-nix-config.cachix.org-1:ziIAJzLVe11AexFTrAY3IZVTZQOWUa5vmFB3eeaW8zw="
CACHIX_TOKEN_ALIAS := "cachix-token"

# ==============================================================================
# STATUS — the look-before-you-leap probe (no token needed; public data)
# ==============================================================================

# One screen: cache reachability (narinfo probe — 404 means reachable
# but empty: nothing pushed yet), the trusted key on THIS machine, and
# the push halves' state (CI secret + local token registration).
# One-screen cache probe: reachability, local trust, push halves.
[group('cachix')]
cachix-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "═══ cache ═══"
    echo "name : {{CACHE_NAME}}"
    echo "url  : {{CACHE_URL}}"
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "{{CACHE_URL}}/nix-cache-info" || echo 000)"
    case "${code}" in
        200) echo "state: reachable (nix-cache-info served; whether a given path is"
             echo "      cached shows up as a narinfo hit during builds — a 404"
             echo "      narinfo only means THAT path is not cached yet)" ;;
        404) echo "state: reachable but NOT serving (cache endpoint misconfigured?)" ;;
        000) echo "state: UNREACHABLE (network / DNS)" ;;
        *)   echo "state: unexpected HTTP ${code}" ;;
    esac
    echo
    echo "═══ trusted on this machine (nix config) ═══"
    if command -v nix >/dev/null 2>&1; then
        nix config show substituters 2>/dev/null | tr ' ' '\n' | grep -F "{{CACHE_URL}}" >/dev/null \
            && echo "substituters : {{CACHE_URL}} present" \
            || echo "substituters : NOT configured (host-side wiring lives in the nixos nix.nix module)"
        nix config show trusted-public-keys 2>/dev/null | tr ' ' '\n' | grep -F "redskaber-nix-config.cachix.org-1:" >/dev/null \
            && echo "trusted key  : pinned" \
            || echo "trusted key  : not pinned in the live config (module-managed hosts get it via nix.nix)"
    else
        echo "nix not on PATH — the wiring is module-managed (nixos core nix module)"
    fi
    echo
    echo "═══ push halves ═══"
    echo "CI   : ci.yml host-toplevels legs push with secret.CACHIX_AUTH_TOKEN (owner verb to set)"
    if just _cachix-token-registered; then
        echo "local: token alias '{{CACHIX_TOKEN_ALIAS}}' REGISTERED — resolve with: just secret-get {{CACHIX_TOKEN_ALIAS}}"
    else
        echo "local: token alias '{{CACHIX_TOKEN_ALIAS}}' not registered — see: just cachix-token"
    fi

# Boolean probe: is the cachix-token alias registered in the secrets
# registry? Exit 0 = yes, non-zero = no. Single implementation for the
# three verbs that branch on it (status / token / push).
[private]
_cachix-token-registered:
    @python3 "{{ROOT}}/scripts/sh/secrets-db.py" q row {{CACHIX_TOKEN_ALIAS}} >/dev/null 2>&1

# ==============================================================================
# TOKEN — the registration flow (the secrets-system preparation)
# ==============================================================================

# Guided entry for the Cachix auth token: registers the secret in the
# registry (three layers, one command) if needed, then records the value
# — one recipe, one intent, no eval-red window in between (a declaration
# without a blob fails the strict eval on a provisioned tree; this verb
# closes both halves before returning).
#
# The token itself comes from https://app.cachix.org/cache/redskaber-nix-config
# → "Auth Tokens" (owner-only page). Re-run any time to rotate the value
# (secret-set is an upsert); the registration step is skipped when the
# alias already exists.
# Register + record the Cachix auth token, guided (one shot).
[group('cachix')]
cachix-token:
    #!/usr/bin/env bash
    set -euo pipefail
    if just _cachix-token-registered; then
        echo "Token secret already registered (alias '{{CACHIX_TOKEN_ALIAS}}')."
    else
        echo "Registering the Cachix token as a secret (alias '{{CACHIX_TOKEN_ALIAS}}')…"
        just secrets-add {{CACHIX_TOKEN_ALIAS}} "nixos/core/base/nix/cachix/auth-token" "Cachix auth token ({{CACHE_NAME}})"
    fi
    echo
    echo "Recording the value now (get it from https://app.cachix.org/cache/{{CACHE_NAME}} → Auth Tokens):"
    just secret-set {{CACHIX_TOKEN_ALIAS}}
    echo
    echo "Inspect:      just secrets-show {{CACHIX_TOKEN_ALIAS}}"
    echo "Then pushes:  just cachix-push /nix/store/…"

# ==============================================================================
# PUSH — local cache fill (token from env or the secrets system)
# ==============================================================================

# Push store paths to {{CACHE_NAME}}. Token resolution order:
#   1. CACHIX_AUTH_TOKEN env (explicit)
#   2. just secret-get cachix-token (the registered blob — leaf-extracted
#      raw value, see _secrets-decrypt)
#
#   just cachix-push /nix/store/… /nix/store/…
#   nix build .#checks.x86_64-linux.module-reachability-check --no-link && just cachix-push $(nix build --print-out-paths .#checks.x86_64-linux.module-reachability-check)
#
# The cachix binary resolves in order: $CACHIX_BIN, PATH, then
# `nix shell nixpkgs#cachix` (flakes machine). Arguments reach this
# script as positional parameters (`set positional-arguments` in the
# root justfile) — quoted args survive intact.
# Push store paths to the cache (token: env, or the secrets system).
[group('cachix')]
cachix-push *paths:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$#" -eq 0 ]; then
        echo "Error: no store paths given." >&2
        echo "  just cachix-push /nix/store/… [more paths]" >&2
        echo "  build + push a check:" >&2
        echo "    nix build .#checks.x86_64-linux.<name> --no-link" >&2
        echo "    just cachix-push \$(nix build --no-link --print-out-paths .#checks.x86_64-linux.<name>)" >&2
        exit 1
    fi
    # 1. token resolution (fail fast, with the guided remedy)
    if [ -n "${CACHIX_AUTH_TOKEN:-}" ]; then
        echo "token: CACHIX_AUTH_TOKEN env"
    elif just _cachix-token-registered; then
        if ! TOKEN="$(just secret-get {{CACHIX_TOKEN_ALIAS}})" || [ -z "${TOKEN}" ]; then
            echo "Error: the token blob is not readable (no value recorded yet?)" >&2
            echo "  just secret-set {{CACHIX_TOKEN_ALIAS}}" >&2
            exit 1
        fi
        export CACHIX_AUTH_TOKEN="${TOKEN}"
        unset TOKEN
        echo "token: secret '{{CACHIX_TOKEN_ALIAS}}' (decrypted)"
    else
        echo "Error: no push token — neither CACHIX_AUTH_TOKEN env nor the '{{CACHIX_TOKEN_ALIAS}}' secret." >&2
        echo "  just cachix-token     # register + record it (guided)" >&2
        exit 1
    fi
    # 2. binary resolution
    if [ -n "${CACHIX_BIN:-}" ]; then
        CACHIX=("${CACHIX_BIN}")
    elif command -v cachix >/dev/null 2>&1; then
        CACHIX=(cachix)
    elif command -v nix >/dev/null 2>&1; then
        CACHIX=(nix shell nixpkgs#cachix -c cachix)
    else
        echo "Error: cachix not found (\$CACHIX_BIN, PATH, or nix shell nixpkgs#cachix)." >&2
        exit 1
    fi
    # 3. push
    "${CACHIX[@]}" push {{CACHE_NAME}} "$@"
