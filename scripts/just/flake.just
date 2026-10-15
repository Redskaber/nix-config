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

# Dry-run update: show what would change without modifying flake.lock.
[group('flake')]
flake-update-dry:
    @cd {{ROOT}} && nix flake update --dry-run

# Show locked versions of all inputs in flake.lock (read-only).
[group('flake')]
flake-lock-show:
    @cd {{ROOT}} && nix flake metadata

# Show all flake outputs (including devShells).
[group('flake')]
flake-show:
    @cd {{ROOT}} && nix flake show
