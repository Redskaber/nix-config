# ==============================================================================
# scripts/just/flake.just
# Responsibility: flake inputs dependency management
#
# The activation lanes (nixos-switch / home-switch / deploy) live in
# scripts/just/deploy.just — inputs here, closures there.
#
# NOTE: imported by justfile; all nix commands use `cd {{ROOT}} &&`
#       to ensure they run in the directory containing flake.nix.
# ==============================================================================

# Update all flake inputs.
[group('flake')]
flake-update-all:
    @cd {{ROOT}} && nix flake update

# Update a single flake input.
[group('flake')]
flake-update pkg:
    @cd {{ROOT}} && nix flake update {{pkg}}

# Update all inputs except sops-nix (keep sops-nix version pinned for stability).
[group('flake')]
flake-update-not-sops:
    @cd {{ROOT}} && nix flake update $(nix eval .#api.inputs --json --no-warn-dirty | jq -r 'keys - ["sops-nix"] | join(" ")')

# Update only inputs whose name ends with -config (external config repos).
[group('flake')]
flake-update-configs:
    @cd {{ROOT}} && nix flake update $(nix eval .#api.inputs --json --no-warn-dirty | jq -r 'keys[] | select(endswith("-config"))')

# Nix has NO --dry-run flag for `nix flake update` — the old one-liner
# died with 'unrecognised flag' on every Nix that ever shipped it
# (verified on the pinned 2.35). The real dry-run is a throwaway copy:
# run the actual update in a temp dir, diff the resulting lock against
# the working tree, discard. (The update reads flake.nix's input
# declarations and flake.lock's current state only — it never
# evaluates outputs, so the two-file copy is a complete stand-in.)
# Dry-run update: preview what `just flake-update-all` would change, without touching flake.lock.
[group('flake')]
flake-update-dry:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ROOT}}"
    TMP="$(mktemp -d)"
    trap 'rm -rf "${TMP}"' EXIT
    cp flake.nix flake.lock "${TMP}/"
    ( cd "${TMP}" && nix flake update )
    if diff -u flake.lock "${TMP}/flake.lock"; then
        echo "dry-run: flake.lock would not change."
    else
        echo "dry-run: the diff above is what 'just flake-update-all' would commit."
    fi

# Show locked versions of all inputs in flake.lock (read-only).
[group('flake')]
flake-lock-show:
    @cd {{ROOT}} && nix flake metadata

# Show all flake outputs (including devShells).
[group('flake')]
flake-show:
    @cd {{ROOT}} && nix flake show
