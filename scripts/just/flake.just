# ==============================================================================
# scripts/just/flake.just
# Responsibility: flake inputs dependency management
#
# NOTE: imported by justfile; all nix commands use `cd {{ROOT}} &&`
#       to ensure they run in the directory containing flake.nix.
# ==============================================================================

# Update all flake inputs.
flake-update-all:
    @cd {{ROOT}} && nix flake update

# Update a single flake input.
flake-update pkg:
    @cd {{ROOT}} && nix flake update {{pkg}}

# Update all inputs except sops-nix (keep sops-nix version pinned for stability).
flake-update-not-sops:
    @cd {{ROOT}} && nix flake update $(nix eval .#api.inputs --json | jq -r 'keys - ["sops-nix"] | join(" ")')

# Update only inputs whose name ends with -config (external config repos).
flake-update-configs:
    @cd {{ROOT}} && nix flake update $(nix eval .#api.inputs --json | jq -r 'keys[] | select(endswith("-config"))')

# Dry-run update: show what would change without modifying flake.lock.
flake-update-dry:
    @cd {{ROOT}} && nix flake update --dry-run

# Show locked versions of all inputs in flake.lock (read-only).
flake-lock-show:
    @cd {{ROOT}} && nix flake metadata

# Show all flake outputs (including devShells).
flake-show:
    @cd {{ROOT}} && nix flake show
