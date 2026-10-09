# ==============================================================================
# scripts/just/disk.just
# Responsibility: disk layout application (disko, T5.13)
#
# A host's disk layout lives in hosts/<hostname>/disk.nix as DATA —
# interpreted by the disko module (registered platform-side in
# platform/nixos/core/base/disk.nix). This module exposes the APPLY
# side of that declaration:
#
#   disk-show <host>     read-only — evaluate the host's layout as JSON
#                        (the eval-level acceptance surface)
#   disk-format <host>  DESTRUCTIVE — partition, format and mount the
#                        declared disks with the pinned script from the
#                        host's OWN closure (config.system.build.
#                        formatMount). Run from an installer/live system
#                        on the target machine; `--dry-run` first is
#                        supported via extra args pass-through.
#
# Contrast with hardware.just (fact GENERATION): these verbs do not
# produce facts — they execute them. The migration flow for a real
# machine is: write hosts/<h>/disk.nix, boot an installer, run
# `just disk-format <h>`, then install/rebuild as usual.
#
# NOTE: imported by justfile; all paths use ROOT (defined in root justfile).
#       The script path comes from the flake in ROOT — run from anywhere.
# ==============================================================================

# Print a host's declared disk layout AS NIXOS WILL SEE IT (read-only
# diagnostic): the interpreter's derivation — fileSystems, swapDevices
# and boot wiring — from disko.devices._config. (The raw .disko.devices
# view holds script-valued internal options and is not JSON-serializable;
# _config IS the eval-level acceptance surface.)
[group('disk')]
disk-show host:
    #!/usr/bin/env bash
    set -euo pipefail
    nix eval --json ".#nixosConfigurations.{{host}}.config.disko.devices._config"

# Apply a host's declared disk layout: partition, format, mount.
# DESTRUCTIVE — the target disks lose their contents. Builds the pinned
# format+mount script from the host's closure (the disko input pinned in
# flake.lock, not a floating github: ref) and runs it with sudo.
# Extra args pass through to the script (e.g. --dry-run).
[group('disk')]
disk-format host *args:
    #!/usr/bin/env bash
    set -euo pipefail
    SCRIPT="$(mktemp -d)/disko-format-mount"
    nix build --print-out-paths ".#nixosConfigurations.{{host}}.config.system.build.formatMount" \
        --option experimental-features "flakes nix-command" > "${SCRIPT}.path" \
        || { echo "Error: could not build the disko script for host '{{host}}'." >&2; exit 1; }
    OUT="$(cat "${SCRIPT}.path")/bin/disko-format-mount"
    rm -f "${SCRIPT}.path"
    echo "Applying hosts/{{host}}/disk.nix with: ${OUT} {{args}}"
    echo "This PARTITIONS AND FORMATS the declared disks — data loss ahead."
    sudo "${OUT}" {{args}}
