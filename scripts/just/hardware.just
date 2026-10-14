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
# `hardware-generate` (see README §hosts for the migration guide), and
# `hardware-migrate` is the ONE-COMMAND flip between them (T19.1): probe
# the report, move what the report cannot express (mounts, kernel
# modules) into the host entry verbatim, flip the wiring, retire the
# legacy file. The end state — exactly one fact source per bare-metal
# host — is machine-locked by the census (tests/lib/shared/targets.nix).
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
#   Both files live in hosts/<hostname>/ (not platform/nixos/system/core/base/).
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
# the machine — the scanner needs root). To then migrate the host entry,
# prefer `just hardware-migrate` (one command — the whole dance below);
# the manual flip, kept as the reference shape:
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

# Migrate the current host from the legacy hardware.nix fact source to the
# declarative facter report — the whole dance in ONE command (T19.1):
#
#   1. PROBE    the machine (root scan — same command as hardware-facter)
#   2. MOVE     what the report CANNOT express: fileSystems, swapDevices
#               and a non-empty boot.kernelModules ride VERBATIM into the
#               host entry (mounts are not report facts; the eventual home
#               is a disko layout, the T5.13 path)
#   3. FLIP     the wiring: the template's hardware.nix import block →
#               hardware.facter.reportPath = ./facter.json
#   4. RETIRE   hosts/<hostname>/hardware.nix (git history is the
#               rollback — revert the migration commit to go back)
#
# Fail-loudly by construction:
#   - the host entry must still carry the TEMPLATE import block
#     (byte-shaped, exactly once) — a hand-reshaped entry is refused
#     and the manual flip is printed instead;
#   - every stanza of the generated hardware.nix must classify as either
#     DERIVED (dropped: the not-detected scanner import, initrd available
#     modules, hostPlatform, CPU microcode — the report + the drive layer
#     re-express them) or MOVED (carried verbatim: mounts, kernel
#     modules) — anything else stops the automation and is printed;
#   - idempotent: an entry already wiring the report exits green.
#
# The end state is locked by the fact-source census
# (tests/lib/shared/targets.nix): exactly ONE source per bare-metal host —
# never both, never neither. One command, four steps: probe the report,
# move the mounts verbatim, flip the wiring, retire the legacy file.
[group('hardware')]
hardware-migrate:
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
    ENTRY="{{ROOT}}/hosts/${HOSTNAME}/default.nix"
    HW="{{ROOT}}/hosts/${HOSTNAME}/hardware.nix"
    OUT="{{ROOT}}/hosts/${HOSTNAME}/facter.json"

    # -- guard: already migrated → green no-op --------------------------
    if grep -qF 'hardware.facter.reportPath' "${ENTRY}" 2>/dev/null; then
        echo "already migrated: ${ENTRY} wires the facter report"
        exit 0
    fi

    # -- guard: a legacy source and an entry to flip ---------------------
    if [[ ! -f "${HW}" ]]; then
        echo "Error: no legacy fact source at ${HW}" >&2
        echo "  (a host already on the facter path — or one whose hardware is" >&2
        echo "   owned elsewhere: wsl/darwin — has nothing to migrate)" >&2
        exit 1
    fi
    if [[ ! -f "${ENTRY}" ]]; then
        echo "Error: host entry ${ENTRY} not found" >&2
        exit 1
    fi

    # -- shape-guard: the entry still carries the template import block --
    # (byte-shaped, exactly once; a hand-reshaped entry needs the manual
    # flip — printed in the error below)
    HITS=$(awk '
        { lines[NR] = $0 }
        END {
            hits = 0
            for (i = 1; i <= NR - 3; i++) {
                if (lines[i]   ~ /^  # Import auto-detected hardware configuration$/ &&
                    lines[i+1] ~ /^  imports = \[$/ &&
                    lines[i+2] ~ /^    \.\/hardware\.nix$/ &&
                    lines[i+3] ~ /^  \];$/) hits++
            }
            print hits
        }' "${ENTRY}")
    if [[ "${HITS}" != "1" ]]; then
        echo "Error: ${ENTRY} does not carry the template import block" >&2
        echo "  (found ${HITS} occurrences — a hand-reshaped entry needs the" >&2
        echo "   manual flip):" >&2
        echo "    1. add    hardware.facter.reportPath = ./facter.json;" >&2
        echo "    2. drop   the imports = [ ./hardware.nix ] block" >&2
        echo "    3. move   fileSystems / swapDevices / kernelModules into the entry" >&2
        echo "    4. delete ${HW}" >&2
        exit 1
    fi

    # -- classify the legacy source: DERIVED vs MOVED vs UNKNOWN ---------
    # MOVED rides into the host entry verbatim; DERIVED is dropped (the
    # report + the drive layer re-express it); anything else refuses.
    UNKNOWN=$(awk '
        # DERIVED multi-line lists (incl. the not-detected scanner import)
        /^  (imports|boot\.initrd\.availableKernelModules|boot\.initrd\.kernelModules|boot\.extraModulePackages) = \[$/ { inlist = 1; next }
        inlist { if ($0 ~ /^  \];$/) inlist = 0; next }
        # DERIVED single-line lists (empty or inline members)
        /^  (imports|boot\.initrd\.(availableKernelModules|kernelModules)|boot\.extraModulePackages) = \[.*\];$/ { next }
        # MOVED: fileSystems."<mnt>" = { … };
        /^  fileSystems\./ { inattr = 1; next }
        inattr { if ($0 ~ /^  \};$/) inattr = 0; next }
        # MOVED: swapDevices = [ … ];
        /^  swapDevices = \[$/ { inlist2 = 1; next }
        inlist2 { if ($0 ~ /^  \];$/) inlist2 = 0; next }
        # MOVED: a non-empty kernelModules line (needs a quoted member)
        /^  boot\.kernelModules = \[.*".*\];$/ { next }
        # DERIVED single-line assignments
        /^  (nixpkgs\.hostPlatform|hardware\.cpu\.[a-z]+\.updateMicrocode) = / { next }
        # module head / comments / blanks
        /^(#|$)/ { next }
        /^\{$/ { next }
        /^\}$/ { next }
        /^\}:$/ { next }
        /^  [a-zA-Z]+,$/ { next }
        /^  \.\.\.$/ { next }
        /^  #/ { next }
        { print "  line " FNR ": " $0 }
    ' "${HW}")
    if [[ -n "${UNKNOWN}" ]]; then
        echo "Error: ${HW} carries stanza(s) this recipe cannot classify:" >&2
        echo "${UNKNOWN}" >&2
        echo "  DERIVED (dropped — the report re-expresses them): imports /" >&2
        echo "    availableKernelModules / initrd kernelModules / extraModule-" >&2
        echo "    Packages / hostPlatform / CPU microcode" >&2
        echo "  MOVED (carried verbatim): fileSystems / swapDevices / kernelModules" >&2
        echo "  Move the unknown stanza by hand (or teach this recipe its class)," >&2
        echo "  then re-run — the census keeps the end state honest either way." >&2
        exit 1
    fi

    # -- 1. PROBE: the report (root scan) --------------------------------
    echo "==> [1/4] scanning hardware for host '${HOSTNAME}' (needs sudo)…"
    sudo nix run --option experimental-features "flakes nix-command" \
        nixpkgs#nixos-facter -- -o "${OUT}"

    # -- 2. MOVE: extract the move-set verbatim --------------------------
    # Three passes, natural reading order (mounts, then swap, then the
    # kernel modules); separators go BETWEEN stanzas, never trailing.
    MOVED=$(mktemp)
    REPL=$(mktemp)
    trap 'rm -f "${MOVED}" "${REPL}"' EXIT
    awk '
        /^  fileSystems\./ { inattr = 1; print; next }
        inattr { print; if ($0 ~ /^  \};$/) inattr = 0; next }
    ' "${HW}" > "${MOVED}"
    awk '
        /^  swapDevices = \[$/ { inlist = 1; print; next }
        inlist { print; if ($0 ~ /^  \];$/) inlist = 0; next }
    ' "${HW}" >> "${MOVED}"
    if ! grep -q 'fileSystems' "${MOVED}"; then
        echo "Error: no fileSystems stanza extracted from ${HW} — a machine" >&2
        echo "without mounts cannot be migrated blindly; refusing." >&2
        exit 1
    fi
    KM=$(awk '
        /^  boot\.kernelModules = \[.*".*\];$/ { print }
    ' "${HW}")
    if [[ -n "${KM}" ]]; then
        printf '\n%s\n' "${KM}" >> "${MOVED}"
    fi

    # -- 3. FLIP: build the replacement and splice it in ------------------
    {
        printf '%s\n' \
            '  # Declarative hardware report — the nixpkgs `hardware.facter` module' \
            '  # derives hostPlatform, initrd modules and CPU microcode from this data.' \
            '  # (Migrated by `just hardware-migrate`; the fact-source census' \
            '  # tests/lib/shared/targets.nix locks "exactly one source per' \
            '  # bare-metal host".)' \
            '  hardware.facter.reportPath = ./facter.json;' \
            '' \
            '  # Mounts are not report facts (facter never generates fileSystems —' \
            '  # the eventual home is a disko layout, the T5.13 path). Moved verbatim' \
            '  # from the retired hardware.nix:'
        cat "${MOVED}"
    } > "${REPL}"
    awk -v repl="${REPL}" '
        { lines[NR] = $0; n = NR }
        END {
            for (i = 1; i <= n; i++) {
                if (i <= n - 3 &&
                    lines[i]   ~ /^  # Import auto-detected hardware configuration$/ &&
                    lines[i+1] ~ /^  imports = \[$/ &&
                    lines[i+2] ~ /^    \.\/hardware\.nix$/ &&
                    lines[i+3] ~ /^  \];$/) {
                    while ((getline l < repl) > 0) print l
                    close(repl)
                    i += 3
                } else print lines[i]
            }
        }' "${ENTRY}" > "${ENTRY}.tmp" && mv "${ENTRY}.tmp" "${ENTRY}"

    # -- post-flip verification: the flip did what it claims --------------
    grep -qF 'hardware.facter.reportPath = ./facter.json;' "${ENTRY}"
    if grep -qF './hardware.nix' "${ENTRY}"; then
        echo "Error: ${ENTRY} still references hardware.nix after the flip" >&2
        exit 1
    fi
    if [[ ! -s "${OUT}" ]]; then
        echo "Error: report ${OUT} missing or empty after the scan" >&2
        exit 1
    fi

    # -- 4. RETIRE: the legacy source --------------------------------------
    rm "${HW}"

    echo
    echo "migrated host '${HOSTNAME}' to the declarative facter report:"
    echo "  report : hosts/${HOSTNAME}/facter.json   (new — root-scanned data)"
    echo "  entry  : hosts/${HOSTNAME}/default.nix   (wiring flipped + stanzas moved)"
    echo "  legacy : hosts/${HOSTNAME}/hardware.nix  (retired — git history is the rollback)"
    echo
    echo "acceptance map (in order):"
    echo "  1. git add hosts/${HOSTNAME}/facter.json"
    echo "     # flakes see TRACKED files only — the census is blind to the"
    echo "     # report until it is added (do this before any eval gate)"
    echo "  2. git diff --staged   # review: report + flip + moved stanzas"
    echo "  3. nix build .#checks.x86_64-linux.lib_shared_targets -L"
    echo "     # the fact-source census: exactly one source, mounts intact"
    echo "     # (adjust the system triple on non-x86_64 machines)"
    echo "  4. just nixos-test ${HOSTNAME}"
    echo "     # activate WITHOUT a boot entry — reboot is the real gate: the"
    echo "     # report-derived initrd must bring the machine up"
    echo "  5. commit as ONE commit (report + flip + retirement). If the"
    echo "     machine misbehaves: git revert — hardware.nix returns."

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
