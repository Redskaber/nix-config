# ==============================================================================
# scripts/just/devenv.just
# Responsibility: dev environment profile management (pdshell-based)
#
# Concepts:
#   profile  — persistent nix develop snapshot under DEV_PROFILE_HOME
#              offline-capable; written by devenv-create* commands
#   use      — enter an existing profile (must be created first)
#   shell    — a devShells attr name: a single language (rust / python …)
#              or a composite (python-machine, nix-derivation-free …)
#
# Profile naming: <username>-<shell> under the shell's LANG directory
#   (DEV_PROFILE_HOME/<lang>/<username>-<shell>). The lang directory is
#   derived from the dev tree (home/env/dev/<lang>/ top-level entries) —
#   composite shells extend their language directory, so python-machine
#   lives under python/ and nix-derivation-free under nix/.
#
#   The shell LIST is the flake's own devShells attrset — the SSOT that
#   also sees inline attrs (nix-derivation-free-security is declared
#   inside nix/default.nix; a file walk alone cannot find it). The
#   hardcoded create-all list this replaced had already drifted that
#   way: python-machine existed in the tree, the README and the census
#   test, yet was never created.
#
# NOTE: imported by justfile; all paths use ROOT (defined in root justfile).
#       nix develop must run under ROOT (where flake.nix lives).
#       DEV_PROFILE_HOME uses $HOME (shell env var), unaffected by CWD.
# ==============================================================================

DEV_PROFILE_HOME    := "$HOME/.local/state/nix/profiles/dev"
DEV_TREE_DIR        := ROOT / "home" / "env" / "dev"

# Resolve username from shared.nix (whitespace-insensitive).
# Used as an inline helper inside shebang blocks — not a recipe.
# Usage: U=$(_dev_username)
_DEV_U_CMD := "grep -oP 'username\\s*=\\s*\"\\K[^\"]+' " + SHARED_NIX_PATH


# --------------------------------------------------------------------------
# Bulk operations
# --------------------------------------------------------------------------

# Create every devShell the flake exposes — the attrset IS the list
# (data-driven: a new shell joins by declaration, not by editing a
# recipe). Zero-shell evals refuse loudly rather than no-op.
# Create all devShells the flake exposes (the attrset is the list).
[group('devenv')]
devenv-create-all:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ROOT}}"
    mapfile -t SHELLS < <(
        nix eval --json .#devShells --no-warn-dirty \
            --apply 'd: builtins.concatLists (builtins.map builtins.attrNames (builtins.attrValues d))' \
            | jq -r '.[]' | sort
    )
    if [[ "${#SHELLS[@]}" -eq 0 ]]; then
        echo "Error: no devShells discovered under .#devShells — refusing an empty run." >&2
        exit 1
    fi
    echo "creating ${#SHELLS[@]} dev profiles: ${SHELLS[*]}"
    for S in "${SHELLS[@]}"; do
        just _dev-create "$S"
    done

# Delete all profile dirs (use before forced rebuild).
[group('devenv')]
devenv-delete-all:
    @rm -rf {{DEV_PROFILE_HOME}}/*

# Delete and rebuild all envs.
[group('devenv')]
devenv-update-all:
    @just devenv-delete-all
    @just devenv-create-all


# --------------------------------------------------------------------------
# Shared core (one implementation behind the verb family)
# --------------------------------------------------------------------------

# Print the LANG directory a shell's profile lives under: the unique
# top-level tree entry the shell name extends (nix-derivation-free →
# nix; the top-level default.nix → default). Falls back to the shell
# name itself when no directory matches (flat profile dir).
[private]
_dev-lang shell:
    #!/usr/bin/env bash
    set -euo pipefail
    S="$1"
    for d in "{{DEV_TREE_DIR}}"/*/; do
        t="$(basename "$d")"
        if [[ "$S" == "$t" || "$S" == "$t"-* ]]; then
            printf '%s\n' "$t"
            exit 0
        fi
    done
    printf '%s\n' "$S"

# Create (or refresh) one devShell's profile by its flake attr name —
# the single writer every create/create-from/create-all verb shares.
[private]
_dev-create shell:
    #!/usr/bin/env bash
    set -euo pipefail
    S="$1"
    U=$({{_DEV_U_CMD}})
    if [[ -z "${U}" ]]; then
        echo "Error: could not parse username from {{SHARED_NIX_PATH}}" >&2; exit 1
    fi
    LANG_DIR="$(just _dev-lang "$S")"
    mkdir -p "{{DEV_PROFILE_HOME}}/${LANG_DIR}"
    cd "{{ROOT}}" && nix develop ".#${S}" --profile "{{DEV_PROFILE_HOME}}/${LANG_DIR}/${U}-${S}"

# Enter an existing devShell profile by its flake attr name.
[private]
_dev-use shell:
    #!/usr/bin/env bash
    set -euo pipefail
    S="$1"
    U=$({{_DEV_U_CMD}})
    if [[ -z "${U}" ]]; then
        echo "Error: could not parse username from {{SHARED_NIX_PATH}}" >&2; exit 1
    fi
    LANG_DIR="$(just _dev-lang "$S")"
    cd "{{ROOT}}" && nix develop "{{DEV_PROFILE_HOME}}/${LANG_DIR}/${U}-${S}"

# Delete one devShell's profile: a whole-language wipe when the shell IS
# the top-level entry (devenv-delete semantics — the lang dir goes), a
# single variant otherwise (devenv-delete-from semantics — siblings and
# the parent dir stay).
[private]
_dev-delete shell:
    #!/usr/bin/env bash
    set -euo pipefail
    S="$1"
    U=$({{_DEV_U_CMD}})
    if [[ -z "${U}" ]]; then
        echo "Error: could not parse username from {{SHARED_NIX_PATH}}" >&2; exit 1
    fi
    LANG_DIR="$(just _dev-lang "$S")"
    if [[ "${LANG_DIR}" == "${S}" ]]; then
        rm -rf "{{DEV_PROFILE_HOME}}/${S}"
    else
        rm -rf "{{DEV_PROFILE_HOME}}/${LANG_DIR}/${U}-${S}"*
    fi


# --------------------------------------------------------------------------
# Single-env CRUD (public verbs — thin delegations over the core)
# --------------------------------------------------------------------------

# Create a single-language profile (e.g. just devenv-create rust).
[group('devenv')]
devenv-create lang:
    @just _dev-create {{lang}}

# Create a composite-language profile (e.g. just devenv-create-from python renpy).
[group('devenv')]
devenv-create-from lang class:
    @just _dev-create "{{lang}}-{{class}}"

# Delete a single-language profile dir.
[group('devenv')]
devenv-delete lang:
    @just _dev-delete {{lang}}

# Delete a composite variant profile (keeps parent dir).
[group('devenv')]
devenv-delete-from lang class:
    @just _dev-delete "{{lang}}-{{class}}"

# Force-rebuild a single-language env.
[group('devenv')]
devenv-update lang:
    @just devenv-delete      {{lang}}
    @just devenv-create      {{lang}}

# Force-rebuild a composite variant env.
[group('devenv')]
devenv-update-from lang class:
    @just devenv-delete-from {{lang}} {{class}}
    @just devenv-create-from {{lang}} {{class}}


# --------------------------------------------------------------------------
# Enter env (no new profile created)
# --------------------------------------------------------------------------

# Enter an existing single-language profile.
[group('devenv')]
devenv-use lang:
    @just _dev-use {{lang}}

# Enter an existing composite variant profile.
[group('devenv')]
devenv-use-from lang class:
    @just _dev-use "{{lang}}-{{class}}"


# --------------------------------------------------------------------------
# Diagnostics
# --------------------------------------------------------------------------

# List all registered devShells in the flake.
[group('devenv')]
devenv-show:
    @cd {{ROOT}} && nix flake show | grep devShells -A25

# Tree-list all created profiles.
[group('devenv')]
devenv-list:
    @eza --tree {{DEV_PROFILE_HOME}}
