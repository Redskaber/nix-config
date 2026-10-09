# ==============================================================================
# scripts/just/hardware.just
# Responsibility: NixOS hardware fact generation (two fact sources)
#
# A host's hardware facts live in hosts/<hostname>/ in ONE of two shapes:
#
#   hardware.nix  LEGACY — auto-detected by nixos-generate-config as a NixOS
#                module (what nixos-generate-config would emit). hosts/nixos
#                still uses this until the report is generated on the machine.
#
#   facter.json   DECLARATIVE (T5.12) — the standard nixos-facter report: raw
#                DATA, interpreted by the nixpkgs `hardware.facter` module
#                (already in the default module list — the host entry wires
#                it with `hardware.facter.reportPath = ./facter.json;` and
#                stops importing hardware.nix). hosts/vm is on this path.
#
# Both are run ON the machine the facts describe; re-run after hardware
# changes. `hardware-facter` is the roadmap path that replaces
# `hardware-generate` (see README §hosts for the migration guide).
#
# Multi-host design:
#   Both files live in hosts/<hostname>/ (not platform/nixos/core/base/).
#   The <hostname> is read from shared.nix at runtime, so this script stays
#   data-driven — no hardcoded host paths.
#
# NOTE: imported by justfile; all paths use ROOT (defined in root justfile).
#       SHARED_NIX_PATH is defined in scripts/just/sops.just.
# ==============================================================================

# Resolve hostname from shared.nix (data-driven, no hardcoded path).
_HOSTNAME_CMD := "grep -oP 'hostName\\s*=\\s*\"\\K[^\"]+' " + SHARED_NIX_PATH

# Detect hardware and write hardware.nix for the current host (overwrites).
# LEGACY fact source — the module-shaped output of nixos-generate-config.
# For the declarative path prefer `hardware-facter` (same info as data).
[group('hardware')]
hardware-generate:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    if [[ ! -f "${SHARED}" ]]; then
        echo "Error: ${SHARED} not found. Run: just shared-generate <username>" >&2
        exit 1
    fi
    HOSTNAME=$({{_HOSTNAME_CMD}} || true)
    if [[ -z "${HOSTNAME}" ]]; then
        echo "Error: could not parse hostName from ${SHARED}" >&2
        exit 1
    fi
    HW_PATH="{{ROOT}}/hosts/${HOSTNAME}/hardware.nix"
    mkdir -p "$(dirname "${HW_PATH}")"
    nixos-generate-config --show-hardware-config > "${HW_PATH}"
    echo "Generated ${HW_PATH} for host '${HOSTNAME}'"

# Print current hardware.nix for the current host (read-only diagnostic).
[group('hardware')]
hardware-show:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    if [[ ! -f "${SHARED}" ]]; then
        echo "Error: ${SHARED} not found." >&2
        exit 1
    fi
    HOSTNAME=$({{_HOSTNAME_CMD}} || true)
    if [[ -z "${HOSTNAME}" ]]; then
        echo "Error: could not parse hostName from ${SHARED}" >&2
        exit 1
    fi
    HW_PATH="{{ROOT}}/hosts/${HOSTNAME}/hardware.nix"
    if [[ ! -f "${HW_PATH}" ]]; then
        echo "Error: ${HW_PATH} not found. Run: just hardware-generate" >&2
        exit 1
    fi
    cat "${HW_PATH}"

# Generate a nixos-facter hardware report for the current host (T5.12).
# The declarative fact source: writes hosts/<hostname>/facter.json (run ON
# the machine — the scanner needs root). Then migrate the host entry:
#   1. add      hardware.facter.reportPath = ./facter.json;
#   2. drop the `imports = [ ./hardware.nix ]` line
#   3. delete hosts/<hostname>/hardware.nix (fileSystems move to the host
#      entry or, later, to the disko layout — facter never generates them).
#
# Schema contract: the report must stay readable by the nixpkgs `hardware.facter`
# module pinned in flake.lock. The scanner command below follows upstream's
# documented quick start (the registry's nixpkgs); if the project bumps
# nixpkgs across a report-schema break, regenerate with the pinned revision:
#   nix shell github:NixOS/nixpkgs/<locked-rev>#nixos-facter
[group('hardware')]
hardware-facter:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    if [[ ! -f "${SHARED}" ]]; then
        echo "Error: ${SHARED} not found. Run: just shared-generate <username>" >&2
        exit 1
    fi
    HOSTNAME=$({{_HOSTNAME_CMD}} || true)
    if [[ -z "${HOSTNAME}" ]]; then
        echo "Error: could not parse hostName from ${SHARED}" >&2
        exit 1
    fi
    OUT="{{ROOT}}/hosts/${HOSTNAME}/facter.json"
    mkdir -p "$(dirname "${OUT}")"
    sudo nix run --option experimental-features "flakes nix-command" \
        nixpkgs#nixos-facter -- -o "${OUT}"
    echo "Generated ${OUT} for host '${HOSTNAME}'"

# List all configured hosts (directories under hosts/).
[group('hardware')]
hardware-list:
    @ls -1 "{{ROOT}}/hosts/"
