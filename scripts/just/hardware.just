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
# A third, read-only fact surface lives here (T17.1): `sound-audit` probes
# the machine's AUDIO form (QEMU device presence / WSLg bridge state) to
# inform the shared-policy sound axis (README debt #9 semantic half). It
# generates no file — it prints evidence and the pre-ruled matrix row from
# docs/guides/sound-adjudication.md. Form detection reads runtime facts
# (kernel release / virt detection), never hostname or policy (the T4.0
# law at the verb level).
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

# Collect debt-#9 semantic-half evidence on THIS machine (read-only).
# Detects the machine form by runtime facts (kernel release / virt
# detection — never hostname or policy), runs the audio-path probe
# battery for that form, and prints the matched row of the decision
# matrix in docs/guides/sound-adjudication.md. Never edits anything:
# the flip itself is a one-data-row change, pre-staged as a comment in
# the host's shared.nix — this verb only turns "what does the machine
# actually have" into evidence.
[group('hardware')]
sound-audit:
    #!/usr/bin/env bash
    set -euo pipefail

    # -- form detection: runtime facts, in precedence order --------------
    osrelease="$(cat /proc/sys/kernel/osrelease 2>/dev/null || true)"
    virt=""
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt="$(systemd-detect-virt -v 2>/dev/null || true)"
    elif cat /proc/cpuinfo 2>/dev/null | grep -q '^flags[[:space:]].* hypervisor'; then
        virt="hypervisor (cpuinfo flag; systemd-detect-virt absent)"
    fi

    echo "sound-audit — debt #9 semantic-half evidence collection (read-only)"
    echo "dossier: docs/guides/sound-adjudication.md"
    echo
    echo "form facts:"
    echo "  /proc/sys/kernel/osrelease = ${osrelease:-<unreadable>}"
    echo "  systemd-detect-virt -v      = ${virt:-none (bare metal)}"
    echo

    if grep -qi microsoft <<<"${osrelease}"; then
        # -- WSL form: the WSLg Windows-side pulse bridge (§B) ----------
        echo "form: WSL (microsoft kernel release) — dossier §B (nixos-wsl)"
        echo "evidence:"
        if [[ -S /mnt/wslg/PulseServer ]]; then
            echo "  /mnt/wslg/PulseServer : socket PRESENT (system-distro server projected)"
        else
            echo "  /mnt/wslg/PulseServer : socket ABSENT (WSLg disabled or unavailable)"
        fi
        echo "  PULSE_SERVER           : ${PULSE_SERVER:-<not set — SSH sessions do not inherit WSLg env; rerun from a WSLg terminal>}"
        echo
        echo "matrix ruling: none — both rows of dossier §B adjudicate none:"
        echo "  socket present -> audio mediation belongs to the host environment"
        echo "  socket absent  -> no audio path exists at all"
        echo "flip (hosts/nixos-wsl/shared.nix, pre-staged as a comment):"
        echo "  sound = shared.enum.sound.none;"
        echo "note: if this machine is the standalone 'wsl' host instead (system"
        echo "layer unowned), the sound axis never enters its closure — nothing"
        echo "to adjudicate."
    elif [[ -n "${virt}" ]]; then
        # -- virtualized guest form: the QEMU audio device (§A) -----------
        echo "form: virtualized guest (${virt}) — dossier §A (vm)"
        echo "evidence:"
        audio_pci=""
        lspci_ran=0
        if command -v lspci >/dev/null 2>&1; then
            lspci_ran=1
            audio_pci="$(lspci -nn 2>/dev/null | grep -iE 'audio|multimedia' || true)"
        else
            echo "  lspci                  : not installed (probe skipped; /proc/asound is authoritative)"
        fi
        if [[ "${lspci_ran}" -eq 1 ]]; then
            if [[ -n "${audio_pci}" ]]; then
                echo "  lspci audio device    : PRESENT"
                echo "${audio_pci}" | sed 's/^/    /'
            else
                echo "  lspci audio device    : none (launcher attached no PCI audio device)"
            fi
        fi
        cards="$(cat /proc/asound/cards 2>/dev/null || true)"
        if [[ -n "${cards}" ]]; then
            echo "  ALSA cards (/proc/asound/cards):"
            echo "${cards}" | sed 's/^/    /'
        else
            echo "  ALSA cards            : none enumerated (a local sound server has nothing to serve)"
        fi
        echo
        echo "matrix ruling: none pre-ruled —"
        echo "  no device: the declared facter report carries none, and the"
        echo "  server-form machine story owns the ruling either way."
        echo "  device present: the owner decides — flip to pipewire only if"
        echo "  sound through the display channel (SPICE/VNC) is actually wanted."
        echo "flip (hosts/vm/shared.nix, pre-staged as a comment):"
        echo "  sound = shared.enum.sound.none;"
    else
        # -- bare metal: no pending adjudication --------------------------
        echo "form: bare metal (no WSL marker, no hypervisor flag) —"
        echo "no pending ruling for this form: the workstation default stands"
        echo "(base policy: sound = pipewire)."
    fi
    echo
    echo "read-only by construction. After landing the flip, run the post-flip"
    echo "verification commands in dossier §6."
