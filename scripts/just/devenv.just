# ==============================================================================
# scripts/just/devenv.just
# Responsibility: dev environment profile management (pdshell-based)
#
# Concepts:
#   profile  — persistent nix develop snapshot under DEV_PROFILE_HOME
#              offline-capable; written by devenv-create* commands
#   use      — enter an existing profile (must be created first)
#   lang     — single-language env  (rust / go / python …)
#   class    — language sub-variant (python-machine / nix-derivation-free …)
#
# Profile naming: <username>-<lang>[-<class>]
#   Username is read from shared.nix at runtime (whitespace-insensitive grep).
#   Every recipe that references a username-prefixed profile path uses a
#   shebang block so the variable is always resolved in the same shell that
#   reads shared.nix — single-process, no cross-recipe variable leakage.
#
# NOTE: imported by justfile; all paths use ROOT (defined in root justfile).
#       nix develop must run under ROOT (where flake.nix lives).
#       DEV_PROFILE_HOME uses $HOME (shell env var), unaffected by CWD.
# ==============================================================================

DEV_PROFILE_HOME    := "$HOME/.local/state/nix/profiles/dev"

# Resolve username from shared.nix (whitespace-insensitive).
# Used as an inline helper inside shebang blocks — not a recipe.
# Usage: U=$(_dev_username)
_DEV_U_CMD := "grep -oP 'username\\s*=\\s*\"\\K[^\"]+' " + SHARED_NIX_PATH


# --------------------------------------------------------------------------
# Bulk operations
# --------------------------------------------------------------------------

# Create all known language envs and composite variants.
devenv-create-all:
    @just devenv-create       c
    @just devenv-create       cpp
    @just devenv-create       go
    @just devenv-create       java
    @just devenv-create       javascript
    @just devenv-create       lisp
    @just devenv-create       lua
    @just devenv-create       nix
    @just devenv-create-from  nix derivation-free
    @just devenv-create-from  nix derivation-unfree
    @just devenv-create-from  nix derivation-free-security
    @just devenv-create       python
    @just devenv-create-from  python renpy
    @just devenv-create       re
    @just devenv-create       rust
    @just devenv-create       typescript
    @just devenv-create       zig
    @just devenv-create       default

# Delete all profile dirs (use before forced rebuild).
devenv-delete-all:
    @rm -rf {{DEV_PROFILE_HOME}}/*

# Delete and rebuild all envs.
devenv-update-all:
    @just devenv-delete-all
    @just devenv-create-all


# --------------------------------------------------------------------------
# Single-env CRUD
# --------------------------------------------------------------------------

# Create a single-language profile (e.g. just devenv-create rust).
devenv-create lang:
    #!/usr/bin/env bash
    set -euo pipefail
    U=$({{_DEV_U_CMD}})
    if [[ -z "${U}" ]]; then
        echo "Error: could not parse username from {{SHARED_NIX_PATH}}" >&2; exit 1
    fi
    mkdir -p "{{DEV_PROFILE_HOME}}/{{lang}}"
    cd "{{ROOT}}" && nix develop .#{{lang}} --profile "{{DEV_PROFILE_HOME}}/{{lang}}/${U}-{{lang}}"

# Create a composite-language profile (e.g. just devenv-create-from python renpy).
devenv-create-from lang class:
    #!/usr/bin/env bash
    set -euo pipefail
    U=$({{_DEV_U_CMD}})
    if [[ -z "${U}" ]]; then
        echo "Error: could not parse username from {{SHARED_NIX_PATH}}" >&2; exit 1
    fi
    mkdir -p "{{DEV_PROFILE_HOME}}/{{lang}}"
    cd "{{ROOT}}" && nix develop .#{{lang}}-{{class}} --profile "{{DEV_PROFILE_HOME}}/{{lang}}/${U}-{{lang}}-{{class}}"

# Delete a single-language profile dir.
devenv-delete lang:
    @rm -rf {{DEV_PROFILE_HOME}}/{{lang}}

# Delete a composite variant profile (keeps parent dir).
devenv-delete-from lang class:
    #!/usr/bin/env bash
    set -euo pipefail
    U=$({{_DEV_U_CMD}})
    if [[ -z "${U}" ]]; then
        echo "Error: could not parse username from {{SHARED_NIX_PATH}}" >&2; exit 1
    fi
    rm -rf "{{DEV_PROFILE_HOME}}/{{lang}}/${U}-{{lang}}-{{class}}"*

# Force-rebuild a single-language env.
devenv-update lang:
    @just devenv-delete      {{lang}}
    @just devenv-create      {{lang}}

# Force-rebuild a composite variant env.
devenv-update-from lang class:
    @just devenv-delete-from {{lang}} {{class}}
    @just devenv-create-from {{lang}} {{class}}


# --------------------------------------------------------------------------
# Enter env (no new profile created)
# --------------------------------------------------------------------------

# Enter an existing single-language profile.
devenv-use lang:
    #!/usr/bin/env bash
    set -euo pipefail
    U=$({{_DEV_U_CMD}})
    if [[ -z "${U}" ]]; then
        echo "Error: could not parse username from {{SHARED_NIX_PATH}}" >&2; exit 1
    fi
    cd "{{ROOT}}" && nix develop .#{{lang}} --profile "{{DEV_PROFILE_HOME}}/{{lang}}/${U}-{{lang}}"

# Enter an existing composite variant profile.
devenv-use-from lang class:
    #!/usr/bin/env bash
    set -euo pipefail
    U=$({{_DEV_U_CMD}})
    if [[ -z "${U}" ]]; then
        echo "Error: could not parse username from {{SHARED_NIX_PATH}}" >&2; exit 1
    fi
    cd "{{ROOT}}" && nix develop .#{{lang}}-{{class}} --profile "{{DEV_PROFILE_HOME}}/{{lang}}/${U}-{{lang}}-{{class}}"


# --------------------------------------------------------------------------
# Diagnostics
# --------------------------------------------------------------------------

# List all registered devShells in the flake.
devenv-show:
    @cd {{ROOT}} && nix flake show | grep devShells -A21

# Tree-list all created profiles.
devenv-list:
    @eza --tree {{DEV_PROFILE_HOME}}
