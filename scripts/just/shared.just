# ==============================================================================
# scripts/just/shared.just
# Responsibility: shared.nix lifecycle management
#
# Design:
#   - No sed in-place patch — patch is runtime mutation, breaks declarative contract
#   - Correct pattern: generate(template + username) → overwrite target file
#   - shared.nix is always produced by this module; edit the template, not the output
#
# File roles:
#   shared.nix.tmpl   plain-text template; __USERNAME__ placeholder; committed to Git
#   shared.nix        generated output; written by just shared-generate; do not edit username manually
#
# NOTE: imported by justfile; all paths use ROOT (defined in root justfile).
# ==============================================================================

SHARED_TMPL_PATH := ROOT / "docs" / "tmpl" / "shared.nix.tmpl"
SHARED_OUT_PATH  := ROOT / "shared.nix"

# Generate shared.nix from template (overwrite). Only valid way to set username.
shared-generate username:
    #!/usr/bin/env bash
    set -euo pipefail
    USERNAME="{{username}}"
    TMPL="{{SHARED_TMPL_PATH}}"
    OUT="{{SHARED_OUT_PATH}}"

    if [[ ! -f "${TMPL}" ]]; then
        echo "Error: template not found: ${TMPL}" >&2
        echo "Hint: create shared.nix.tmpl with __USERNAME__ as placeholder." >&2
        exit 1
    fi

    sed "s|__USERNAME__|${USERNAME}|g" "${TMPL}" > "${OUT}"
    echo "Generated ${OUT} with username='${USERNAME}' from ${TMPL}"

# Print username parsed from shared.nix (read-only diagnostic).
shared-show-username:
    #!/usr/bin/env bash
    set -euo pipefail
    OUT="{{SHARED_OUT_PATH}}"
    if [[ ! -f "${OUT}" ]]; then
        echo "Error: ${OUT} not found. Run: just shared-generate <username>" >&2
        exit 1
    fi
    CURRENT=$(grep -oP 'username\s*=\s*"\K[^"]+' "${OUT}" || true)
    if [[ -z "${CURRENT}" ]]; then
        echo "Error: could not parse username from ${OUT}" >&2
        exit 1
    fi
    echo "Current username in ${OUT}: '${CURRENT}'"

# Verify template exists and contains at least one __USERNAME__ placeholder.
shared-validate:
    #!/usr/bin/env bash
    set -euo pipefail
    TMPL="{{SHARED_TMPL_PATH}}"
    if [[ ! -f "${TMPL}" ]]; then
        echo "FAIL: template missing: ${TMPL}" >&2
        exit 1
    fi
    COUNT=$(grep -c '__USERNAME__' "${TMPL}" || true)
    if [[ "${COUNT}" -eq 0 ]]; then
        echo "WARN: no __USERNAME__ placeholder found in ${TMPL}" >&2
    else
        echo "OK: ${COUNT} __USERNAME__ placeholder(s) found in ${TMPL}"
    fi
