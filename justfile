set shell := ["bash", "-c"]

# ==============================================================================
# Global — single source of truth
# ==============================================================================
# ROOT: just changes CWD to each imported sub-module's directory when running
#       recipes. All sub-module paths must therefore be anchored with ROOT
#       (the project root). ROOT is defined here and referenced by all modules.
#
# username: must be passed explicitly — do NOT use `id -un`.
#   This justfile may run under a LiveISO where the current user is nixos/root,
#   not the target user.
ROOT := justfile_directory()

# ==============================================================================
# Sub-module imports
# ==============================================================================
import "scripts/just/commit.just"
import "scripts/just/shared.just"
import "scripts/just/hardware.just"
import "scripts/just/flake.just"
import "scripts/just/devenv.just"
import "scripts/just/sops.just"


# ==============================================================================
# Private guards
# ==============================================================================
# Assert shared.nix exists and username is parseable (pre-condition for POST-BOOTSTRAP ops).
# NOTE: SHARED_NIX_PATH is defined in scripts/just/sops.just and is available
#       here because just merges variables from all imported modules globally.
_assert-shared:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    if [[ ! -f "${SHARED}" ]]; then
        echo "Error: ${SHARED} not found." >&2
        echo "Run: just shared-generate <username>" >&2
        exit 1
    fi
    U=$(grep -oP 'username\s*=\s*"\K[^"]+' "${SHARED}" || true)
    if [[ -z "${U}" ]]; then
        echo "Error: could not parse username from ${SHARED}" >&2
        exit 1
    fi


# ==============================================================================
# Main entry point
# ==============================================================================
# Full init for a new machine: shared.nix → hardware.nix → sops infra.
init username:
    @just shared-generate {{username}}
    @just hardware-generate
    @just sops-init
