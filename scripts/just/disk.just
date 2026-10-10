# ==============================================================================
# scripts/just/disk.just
# Responsibility: disk layout application + state-strategy inspection
#                 (disko T5.13, impermanence T5.14)
#
# A host's disk layout lives in hosts/<hostname>/disk.nix as DATA —
# interpreted by the disko module (registered platform-side in
# platform/nixos/core/base/disk.nix). Its state strategy lives in
# hosts/<hostname>/persist.nix as DATA — interpreted by impermanence
# and the rollback machinery (registered platform-side in
# platform/nixos/core/base/impermanence.nix). This module exposes
# the APPLY and INSPECT side of those declarations:
#
#   disk-show <host>     read-only — evaluate the host's layout as JSON
#                        (the eval-level acceptance surface)
#   persist-show <host>  read-only — evaluate the host's state contract:
#                        the persistence inventory, the derived
#                        neededForBoot wiring and the ephemeral-root
#                        rollback recipe (empty when the host's root is
#                        persistent — no declaration, no effect)
#   disk-format <host>  DESTRUCTIVE — partition, format and mount the
#                        declared disks with the pinned script from the
#                        host's OWN closure (config.system.build.
#                        formatMount). Run from an installer/live system
#                        on the target machine; `--dry-run` first is
#                        supported via extra args pass-through.
#
# Contrast with hardware.just (fact GENERATION): these verbs do not
# produce facts — they execute or inspect them. The migration flow
# for a real machine is: write hosts/<h>/disk.nix, boot an installer,
# run `just disk-format <h>`, then install/rebuild as usual.
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

# Print a host's DECLARED state contract (read-only diagnostic): the
# persistence inventory (what survives), whether the interpreter wired
# each persistence path early (neededForBoot), and the derived
# ephemeral-root rollback recipe (postResumeCommands — empty on
# persistent-root hosts; the recipe's device/subvol/retention come from
# the layout facts, so what you see is what boot will run).
[group('disk')]
persist-show host:
    #!/usr/bin/env bash
    set -euo pipefail
    nix eval --json ".#nixosConfigurations.{{host}}.config" --apply 'c: {
        persistence = builtins.mapAttrs (_: p: {
          directories = map (d: d.dirPath) p.directories;
          files = map (f: f.filePath) p.files;
          inherit (p) hideMounts enable;
        }) c.environment.persistence;
        ephemeral = {
          enable = c.redskaber.impermanence.ephemeral-root.enable;
          retain-days = c.redskaber.impermanence.ephemeral-root.retain-days;
          recipe = c.boot.initrd.postResumeCommands;
          recipe-systemd = c.boot.initrd.systemd.services.ephemeral-root.script or "";
        };
      }'

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
