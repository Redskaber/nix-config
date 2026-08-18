# ==============================================================================
# scripts/just/services.just
# Responsibility: on-demand service management (install but not autostart)
#
# Design:
#   NixOS service management has 3 layers:
#     1. enable=true      → install (generate systemd unit file)
#     2. wantedBy=[...]   → nix controls autostart symlink (declarative)
#     3. systemctl enable/disable → user controls autostart (imperative, persistent)
#
#   With service-profile=dev-on-demand, wantedBy=[] means nix does NOT manage
#   the autostart symlink. Users control it via `systemctl enable/disable`:
#     - `just service-enable postgresql`  → systemctl enable (persist across reboots)
#     - `just service-disable postgresql` → systemctl disable (no autostart)
#     - `just service-start postgresql`   → systemctl start (immediate, not persistent)
#     - `just service-stop postgresql`    → systemctl stop (immediate, not persistent)
#
#   This design ensures:
#     - nix files only decide "install" + "first-boot default"
#     - After first boot, service state is managed by user via systemctl
#     - No `nixos-rebuild` needed to change service start/stop state
#     - `systemctl enable/disable` persists across reboots AND rebuilds
#
# Usage:
#   just service-start postgresql       # start now (not persistent)
#   just service-stop mysql             # stop now (not persistent)
#   just service-enable postgresql      # enable autostart on boot (persistent)
#   just service-disable mysql          # disable autostart on boot (persistent)
#   just service-status postgresql      # check status
#   just service-restart postgresql     # restart
#   just service-is-enabled postgresql  # check if enabled
#   just db-list                        # list all database services
#   just db-start postgresql            # alias for service-start
#   just db-stop postgresql             # alias for service-stop
#   just db-enable postgresql           # alias for service-enable
#   just db-disable postgresql          # alias for service-disable
#   just autostart-list                 # list all enabled services
# ==============================================================================

# Start a systemd service (immediate, not persistent across reboot).
service-start name:
    @sudo systemctl start {{name}}

# Stop a systemd service (immediate, not persistent across reboot).
service-stop name:
    @sudo systemctl stop {{name}}

# Enable a systemd service for autostart on boot (persistent, survives rebuild).
service-enable name:
    @sudo systemctl enable {{name}}
    @echo "✓ {{name}} will autostart on boot (persistent across rebuilds)"

# Disable a systemd service from autostart on boot (persistent, survives rebuild).
service-disable name:
    @sudo systemctl disable {{name}}
    @echo "✓ {{name}} will NOT autostart on boot (persistent across rebuilds)"

# Check if a systemd service is enabled for autostart.
service-is-enabled name:
    @systemctl is-enabled {{name}} 2>&1

# Check status of a systemd service.
service-status name:
    @systemctl status {{name}} --no-pager 2>&1 | head -15

# Restart a systemd service.
service-restart name:
    @sudo systemctl restart {{name}}

# List all database services (installed, from shared.nix).
db-list:
    @echo "Database services (from shared.nix service-profile):"
    @nix eval .#nixosConfigurations.kilig-nixos.config.systemd.services --apply 'svc: builtins.filter (n: builtins.match ".*(mysql|postgres|redis|mongodb).*" n != null) (builtins.attrNames svc)' --json 2>/dev/null | jq -r '.[]' || echo "  (run from project root)"

# Start a database service (alias for service-start).
db-start name:
    @just service-start {{name}}

# Stop a database service (alias for service-stop).
db-stop name:
    @just service-stop {{name}}

# Enable a database service for autostart (alias for service-enable).
db-enable name:
    @just service-enable {{name}}

# Disable a database service from autostart (alias for service-disable).
db-disable name:
    @just service-disable {{name}}

# List all services enabled for autostart (systemctl is-enabled).
autostart-list:
    @systemctl list-unit-files --type=service --state=enabled --no-pager 2>&1 | head -30
