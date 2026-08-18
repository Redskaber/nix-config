# ==============================================================================
# scripts/just/hardware.just
# Responsibility: NixOS hardware configuration generation
#
# hardware.nix is auto-detected from the current machine by nixos-generate-config.
# Run once during initial setup; re-run only after hardware changes.
#
# Multi-host design:
#   hardware.nix lives in hosts/<hostname>/hardware.nix (not nixos/core/base/).
#   The <hostname> is read from shared.nix at runtime, so this script stays
#   data-driven — no hardcoded host paths.
#
# Prerequisite disk layout (completed during nixos-install):
#   /      — root partition
#   /boot  — EFI/boot partition
#   swap   — swap space (optional)
#
# NOTE: imported by justfile; all paths use ROOT (defined in root justfile).
#       SHARED_NIX_PATH is defined in scripts/just/sops.just.
# ==============================================================================

# Resolve hostname from shared.nix (data-driven, no hardcoded path).
_HOSTNAME_CMD := "grep -oP 'hostName\\s*=\\s*\"\\K[^\"]+' " + SHARED_NIX_PATH

# Detect hardware and write hardware.nix for the current host (overwrites).
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

# List all configured hosts (directories under hosts/).
hardware-list:
    @ls -1 "{{ROOT}}/hosts/"
