# ==============================================================================
# scripts/just/deploy.just
# Responsibility: host-closure activation lanes (local + remote)
#
# Three activation lanes over one closure family (CI locks the
# equivalence — the same toplevels nixos-rebuild builds):
#   nixos-rebuild  nixos-switch / nixos-test / nixos-boot   the local lane
#   home-manager   home-switch                               the HM-only lane
#   colmena        deploy / deploy-local                     the remote lane
#
# Hosts are enumerated from hosts/ by the flake itself — no hardcoded
# list here (hosts-list / home-targets / deploy-list are the read-only
# faces of that enumeration). Adding a machine = mkdir hosts/<name> +
# files; every verb below picks it up automatically.
#
# NOTE: imported by justfile; all nix commands use `cd {{ROOT}} &&`
#       to ensure they run in the directory containing flake.nix.
# ==============================================================================

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

# Set the boot generation WITHOUT activating: build + register
# the next-boot closure; the running system stays untouched until
# reboot. The safer remote/rollback-flavoured deploy — wimpy's
# push-host-boot pattern: flip the machine on your own schedule,
# `nixos-rebuild list-generations` to inspect, rollback stays a
# boot-menu entry away.
# Set the NEXT-BOOT generation without activating (the safe remote flip).
[group('deploy')]
nixos-boot host:
    @cd {{ROOT}} && sudo nixos-rebuild boot --flake .#{{host}}

# Home Manager switch for the policy user on a specific host
# ('just home-switch nixos' → kilig@nixos).
# Home-Manager switch for the policy user on a host.
[group('deploy')]
home-switch host:
    @cd {{ROOT}} && USER=$$(grep -oP 'username\s*=\s*"\K[^"]+' {{SHARED_NIX_PATH}}) && \
        nix run home-manager -- switch --flake ".#$${USER}@{{host}}"

# ── Colmena deploy verbs ──────────────────────────────────────────
# The remote-deploy lane: `just deploy <host>` pushes the SAME closures
# nixos-rebuild builds (CI locks the equivalence), over ssh as the
# policy user. CLI pinned to v0.5.0 to match the flake input — colmena
# 0.4 and older read the deprecated `colmena` output and cannot see
# colmenaHive at all; nixpkgs' packaged colmena is channel-lagged, so
# the tag (not nixpkgs#) is the pin that stays in lockstep.

# List colmena's deployment scope (the classifier's nixosHosts — darwin
# and standalone-HM hosts deploy by their own verbs, never colmena).
# List colmena's deployment scope (nixos hosts only).
[group('deploy')]
deploy-list:
    @cd {{ROOT}} && nix eval .#api.targets.nixosHosts --json

# Remote-deploy one host: build, upload, activate (switch semantics —
# the generation flips live; rollback stays a `colmena apply --rollback`
# away). targetUser comes from the policy; coordinates from
# hosts/<host>/deploy.nix (node name as host until it says otherwise).
# Remote-deploy one host: build, upload, activate (ssh, colmena).
[group('deploy')]
deploy host:
    @cd {{ROOT}} && nix run github:zhaofengli/colmena/v0.5.0 -- apply --on {{host}}

# Deploy to the machine you are ON (needs allowLocalDeployment on the
# node — hosts/nixos/deploy.nix carries it). The sudo-parity of
# nixos-switch for the colmena lane.
# Colmena apply-local to THIS machine (sudo parity of nixos-switch).
[group('deploy')]
deploy-local:
    @cd {{ROOT}} && nix run github:zhaofengli/colmena/v0.5.0 -- apply-local --sudo
