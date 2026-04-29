# ==============================================================================
# scripts/just/hardware.just
# Responsibility: NixOS hardware configuration generation
#
# hardware.nix is auto-detected from the current machine by nixos-generate-config.
# Run once during initial setup; re-run only after hardware changes.
#
# Prerequisite disk layout (completed during nixos-install):
#   /      — root partition
#   /boot  — EFI/boot partition
#   swap   — swap space (optional)
#
# NOTE: imported by justfile; all paths use ROOT (defined in root justfile).
# ==============================================================================

NIXOS_HARDWARE_PATH := ROOT / "nixos/core/base/hardware.nix"

# Detect hardware and write hardware.nix (overwrites existing file).
hardware-generate:
    @nixos-generate-config --show-hardware-config > {{NIXOS_HARDWARE_PATH}}
    @echo "Generated {{NIXOS_HARDWARE_PATH}}"

# Print current hardware.nix (read-only diagnostic).
hardware-show:
    @cat {{NIXOS_HARDWARE_PATH}}
