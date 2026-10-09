# ==============================================================================
# scripts/just/flake.just
# Responsibility: flake inputs dependency management
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
    @cd {{ROOT}} && nix flake update $(nix eval .#api.inputs --json | jq -r 'keys - ["sops-nix"] | join(" ")')

# Update only inputs whose name ends with -config (external config repos).
[group('flake')]
flake-update-configs:
    @cd {{ROOT}} && nix flake update $(nix eval .#api.inputs --json | jq -r 'keys[] | select(endswith("-config"))')

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

# ── Host-keyed targets (T2.4) ─────────────────────────────────────────────
# Hosts are enumerated from hosts/ by the flake itself — no hardcoded list
# here. Adding a machine = mkdir hosts/<name> + files, then these recipes
# pick it up automatically.

# List every evaluable host (data-driven from hosts/ via nixosConfigurations).
[group('deploy')]
hosts-list:
    @cd {{ROOT}} && nix eval .#nixosConfigurations --apply builtins.attrNames --json

# List every standalone home-manager target (per host).
[group('deploy')]
home-targets:
    @cd {{ROOT}} && nix eval .#homeConfigurations --apply builtins.attrNames --json

# NixOS rebuild switch for a specific host ('just nixos-switch nixos').
[group('deploy')]
nixos-switch host:
    @cd {{ROOT}} && sudo nixos-rebuild switch --flake .#{{host}}

# NixOS rebuild test (no boot entry) for a specific host.
[group('deploy')]
nixos-test host:
    @cd {{ROOT}} && sudo nixos-rebuild test --flake .#{{host}}

# Home Manager switch for the policy user on a specific host
# ('just home-switch nixos' → kilig@nixos).
[group('deploy')]
home-switch host:
    @cd {{ROOT}} && USER=$$(grep -oP 'username\s*=\s*"\K[^"]+' {{SHARED_NIX_PATH}}) && \
        nix run home-manager -- switch --flake ".#$${USER}@{{host}}"
