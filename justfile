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
import "scripts/just/disk.just"
import "scripts/just/flake.just"
import "scripts/just/devenv.just"
import "scripts/just/secrets.just"
import "scripts/just/dump.just"
import "scripts/just/services.just"

# ==============================================================================
# Start here — the map of the whole command surface
# ==============================================================================
# `just` with no arguments prints this map. Every entry point below is
# discoverable: `just --list` shows the grouped verb surface,
# `just secrets-guide` prints the secrets lifecycle map.

# Print the start-here map: new machine, secrets, deploy, everything else.
[private]
default:
    @echo ""
    @echo "nix-config — start here"
    @echo ""
    @echo "  new machine, day one        just init <username>"
    @echo "                              (= shared-generate + hardware-generate + secrets-init)"
    @echo ""
    @echo "  secrets (values)            just secret-set <alias> · secret-get · secrets-list"
    @echo "  secrets (keys & policy)     just secrets-guide   ← the lifecycle map"
    @echo ""
    @echo "  deploy                      just nixos-switch <host>   (NixOS)"
    @echo "                              just home-switch <host>    (home-manager only)"
    @echo "                              just hosts-list            (what is deployable)"
    @echo ""
    @echo "  services / flake / dev      just --list   (grouped verb surface)"
    @echo ""
    @echo "  docs: README.md · docs/secrets/rotation.md · just <recipe> --evaluate"
    @echo ""

# ==============================================================================
# Private guards
# ==============================================================================
# Assert shared.nix exists and username is parseable (pre-condition for POST-BOOTSTRAP ops).
# NOTE: SHARED_NIX_PATH is defined in scripts/just/secrets.just and is available
# here because just merges variables from all imported modules globally.
[private]
_assert-shared:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{ SHARED_NIX_PATH }}"
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
#   just init <username>                    user-only sops baseline
#   just init <username> <alias> <age1…>    direct dual-key bootstrap
#                                           (generate the host keypair first:
#                                            just key-new-host <alias>)
#
# Full init for a new machine: shared.nix → hardware.nix → sops infra.
[group('bootstrap')]
init username host_alias="" host_pubkey="":
    @just shared-generate {{ username }}
    @just hardware-generate
    @just secrets-init "{{ host_alias }}" "{{ host_pubkey }}"
