# ==============================================================================
# scripts/just/sops.just
# Responsibility: Age key + SOPS encryption lifecycle management
#
# Layer architecture:
#   ┌──────────────────────────────────────────────────────────────────┐
#   │  TMPL LAYER      docs/tmpl/sops/**                               │
#   │                  static YAML templates; version-controlled       │
#   │                  placeholders: __USERNAME__ / __AGE_PUBLIC_KEY__ │
#   ├──────────────────────────────────────────────────────────────────┤
#   │  KEY LAYER       age-keygen → ~/.config/sops/age/keys.txt        │
#   ├──────────────────────────────────────────────────────────────────┤
#   │  RULE LAYER      .sops.yaml  (generated from template)           │
#   ├──────────────────────────────────────────────────────────────────┤
#   │  PLAIN LAYER     secrets/plan/**  plaintext instances            │
#   │                  tmpl → sed(__USERNAME__) → overwrite            │
#   ├──────────────────────────────────────────────────────────────────┤
#   │  CIPHER LAYER    secrets/chipr/** SOPS-encrypted                 │
#   │                  interactive input → sops encrypt → overwrite    │
#   └──────────────────────────────────────────────────────────────────┘
#
# Design principles:
#   - Data-driven: all secret paths read from shared.nix at runtime; zero
#     hardcoded paths in sops.just. Adding a new secret = edit shared.nix.tmpl
#     + add one template YAML file. No code changes needed here.
#
#   - Single derivation rule (template path ↔ secret REL path):
#     The value in shared.nix (e.g. "nixos/core/srv/db/mongodb/users/kilig/password")
#     IS the template file path relative to SECRETS_TMPL_PATH, with the real
#     username reversed back to __USERNAME__. Derivation:
#       TMPL_REL = REL | sed "s|/${U}/|/__USERNAME__/|g; s|redis-${U}|redis-__USERNAME__|g"
#       TMPL     = SECRETS_TMPL_PATH / TMPL_REL + ".yaml"
#     This rule is defined ONCE and applied identically in _sops-plan-gen and
#     _sops-chipr-write, so the two layers are always structurally in sync.
#
#   - Generic encrypt writer: _sops-chipr-write handles all secrets. Per-secret
#     recipes (sops-chipr-create-*) are thin wrappers supplying only what differs:
#     prompt label, template placeholder, and optional transform.
#
#   - _sops-mkdir iterates all nixos.* secret values in shared.nix to create
#     directories — no path list to maintain separately.
#
#   - Generate, don't mutate: overwrite, never in-place patch.
#   - plan / chipr fully separated — different lifecycle, different audience.
#   - sops-init only sets up infrastructure; no interactive prompts.
#   - Destroy operations are granular.
#
# Information source (all stages read from shared.nix):
#   BOOTSTRAP      shared.nix must exist; _sops-mkdir and _sops-write-rules read it
#   POST-BOOTSTRAP paths auto-derived from shared.nix secrets.* values at runtime
#
# NOTE: imported by justfile; all paths use ROOT (defined in root justfile).
#
# Template directory mirrors the secret path hierarchy under docs/tmpl/sops/:
#   nixos/core/base/user/__USERNAME__/password.yaml
#   nixos/core/base/nix/users/__USERNAME__/github/access-token.yaml
#   nixos/core/srv/db/{mongodb,mysql,postgresql,redis}/users/.../password.yaml
#   sops-rules.yaml.tmpl
#
# YAML leaf-key convention (required by sops-nix path lookup):
#   sops-nix splits a secret key on "/" and walks the YAML hierarchy. The leaf
#   key in the template MUST equal the last path segment.
#   Example: key "nixos/core/base/nix/users/kilig/github/access-token"
#            → YAML leaf key: "access-token"  (singular — matches path segment)
#            → VALUE may be:  "access-tokens = github.com=TOKEN"  (nix.conf line)
# ==============================================================================

SECRETS_PATH       := ROOT          / "secrets"
SECRETS_CHIPR_PATH := SECRETS_PATH  / "chipr"
SECRETS_PLAN_PATH  := SECRETS_PATH  / "plan"
SECRETS_TMPL_PATH  := ROOT          / "docs" / "tmpl" / "sops"
DOT_SOPS_FILENAME  := ROOT          / ".sops.yaml"
SECRETS_KEYS_PATH  := "$HOME/.config/sops/age"
SECRETS_KEYFILE    := SECRETS_KEYS_PATH / "keys.txt"
SHARED_NIX_PATH    := ROOT          / "shared.nix"


# ==============================================================================
# Init (BOOTSTRAP)
# ==============================================================================

# Init sops infra: dirs + age key + .sops.yaml rules.
sops-init:
    @just _assert-shared
    @just _sops-mkdir
    @just _sops-keygen
    @just _sops-write-rules

# Init sops infra and also generate all plaintext template instances.
sops-init-with-plan:
    @just sops-init
    @just sops-plan-create-all


# ==============================================================================
# KEY LAYER — Age key management
# ==============================================================================

# Print current age public key.
sops-key-show:
    @age-keygen -y {{SECRETS_KEYFILE}}

# Destroy age key file (irreversible — encrypted files become unreadable).
sops-key-destroy:
    @rm -rf {{SECRETS_KEYS_PATH}}
    @echo "Destroyed age key at {{SECRETS_KEYS_PATH}}"


# ==============================================================================
# RULE LAYER — .sops.yaml management
# ==============================================================================

# Regenerate .sops.yaml from template (use after key rotation).
sops-rules-regen:
    @just _assert-shared
    @just _sops-write-rules

# Delete .sops.yaml.
sops-rules-destroy:
    @rm -f {{DOT_SOPS_FILENAME}}


# ==============================================================================
# PLAIN LAYER — plaintext template instances (plan)
# ==============================================================================
# All paths derived from shared.nix at runtime. To add a new secret:
#   (1) add to shared.nix.tmpl  (2) add template YAML file  (3) add one line below.

# Generate all plaintext template instances (data-driven, paths from shared.nix).
sops-plan-create-all:
    @just _assert-shared
    @just _sops-plan-gen "nixos.core.base.user.password"
    @just _sops-plan-gen "nixos.core.base.nix.user.github.access-token"
    @just _sops-plan-gen "nixos.core.srv.db.mongodb.user.password"
    @just _sops-plan-gen "nixos.core.srv.db.mysql.root.password"
    @just _sops-plan-gen "nixos.core.srv.db.mysql.user.password"
    @just _sops-plan-gen "nixos.core.srv.db.postgresql.user.password"
    @just _sops-plan-gen "nixos.core.srv.db.redis.user.password"
    @echo "All plan instances created under {{SECRETS_PLAN_PATH}}"

# Delete all plaintext template instances.
sops-plan-destroy:
    @rm -rf {{SECRETS_PLAN_PATH}}
    @echo "Destroyed {{SECRETS_PLAN_PATH}}"


# ==============================================================================
# CIPHER LAYER — encrypt (POST-BOOTSTRAP)
# ==============================================================================
# Each recipe is a thin wrapper: supplies key + prompt + placeholder [+ transform].
# All path resolution and I/O are handled by the generic _sops-chipr-write.
# To add a new secret: add one sops-chipr-create-* recipe (4 lines) here.

# Encrypt user system password (stored as mkpasswd sha-512 hash).
sops-chipr-create-userpwd:
    @just _assert-shared
    @just _sops-chipr-write \
        "nixos.core.base.user.password" \
        "User system password" \
        "<YOUR_USER_PASSWORD_FROM_MKPASSWD>" \
        "mkpasswd"

# Encrypt Nix/GitHub access token.
sops-chipr-create-nix:
    @just _assert-shared
    @just _sops-chipr-write \
        "nixos.core.base.nix.user.github.access-token" \
        "GitHub access token" \
        "<YOUR_GITHUB_TOKEN>"

# Encrypt MongoDB user password.
sops-chipr-create-mongodb:
    @just _assert-shared
    @just _sops-chipr-write \
        "nixos.core.srv.db.mongodb.user.password" \
        "MongoDB password" \
        "<YOUR_MONGODB_PASSWORD>"

# Encrypt MySQL root + user passwords (two secrets, one command).
sops-chipr-create-mysql:
    @just _assert-shared
    @just _sops-chipr-write \
        "nixos.core.srv.db.mysql.root.password" \
        "MySQL root password" \
        "<YOUR_MYSQL_ROOT_PASSWORD>"
    @just _sops-chipr-write \
        "nixos.core.srv.db.mysql.user.password" \
        "MySQL user password" \
        "<YOUR_MYSQL_USER_PASSWORD>"

# Encrypt PostgreSQL user password.
sops-chipr-create-postgresql:
    @just _assert-shared
    @just _sops-chipr-write \
        "nixos.core.srv.db.postgresql.user.password" \
        "PostgreSQL password" \
        "<YOUR_POSTGRESQL_PASSWORD>"

# Encrypt Redis user password.
sops-chipr-create-redis:
    @just _assert-shared
    @just _sops-chipr-write \
        "nixos.core.srv.db.redis.user.password" \
        "Redis password" \
        "<YOUR_REDIS_PASSWORD>"

# Interactively encrypt all secrets in order.
sops-chipr-create-all:
    @just sops-chipr-create-userpwd
    @just sops-chipr-create-nix
    @just sops-chipr-create-mongodb
    @just sops-chipr-create-mysql
    @just sops-chipr-create-postgresql
    @just sops-chipr-create-redis


# ==============================================================================
# CIPHER LAYER — decrypt (POST-BOOTSTRAP)
# ==============================================================================

# Decrypt and print user system password.
sops-chipr-read-userpwd:
    @just _assert-shared
    @just _sops-chipr-read "nixos.core.base.user.password"

# Decrypt and print Nix/GitHub token.
sops-chipr-read-nix:
    @just _assert-shared
    @just _sops-chipr-read "nixos.core.base.nix.user.github.access-token"

# Decrypt and print MongoDB password.
sops-chipr-read-mongodb:
    @just _assert-shared
    @just _sops-chipr-read "nixos.core.srv.db.mongodb.user.password"

# Decrypt and print MySQL root + user passwords.
sops-chipr-read-mysql:
    @just _assert-shared
    @just _sops-chipr-read "nixos.core.srv.db.mysql.root.password"
    @just _sops-chipr-read "nixos.core.srv.db.mysql.user.password"

# Decrypt and print PostgreSQL password.
sops-chipr-read-postgresql:
    @just _assert-shared
    @just _sops-chipr-read "nixos.core.srv.db.postgresql.user.password"

# Decrypt and print Redis password.
sops-chipr-read-redis:
    @just _assert-shared
    @just _sops-chipr-read "nixos.core.srv.db.redis.user.password"


# ==============================================================================
# CIPHER LAYER — destroy
# ==============================================================================

# Delete all encrypted secret dirs (irreversible).
sops-chipr-destroy:
    @rm -rf {{SECRETS_CHIPR_PATH}}
    @echo "Destroyed {{SECRETS_CHIPR_PATH}}"


# ==============================================================================
# Global destroy (granular)
# ==============================================================================

# Destroy all sops artifacts: key + rules + all secrets (irreversible).
sops-destroy-all:
    @just sops-plan-destroy
    @just sops-chipr-destroy
    @just sops-rules-destroy
    @just sops-key-destroy
    @echo "All sops artifacts destroyed."


# ==============================================================================
# Private helpers — shared.nix parsing
# ==============================================================================

# Read a string value from shared.nix by dotted key; whitespace-insensitive.
# Usage:  _shared-get <path> <dotted.key>
# Returns the matched value (no quotes); empty string if not found.
_shared-get path key:
    #!/usr/bin/env bash
    set -euo pipefail
    pat=$(printf '%s' "{{key}}" | sed 's/\./\\./g')
    grep -oP "${pat}"'\s*=\s*"\K[^"]+' "{{path}}" || true


# ==============================================================================
# Private — infrastructure setup
# ==============================================================================

# Create all secret dirs (plan/ and chipr/) driven entirely by shared.nix.
# Greps every nixos.* secret value → dirname → mkdir. Zero hardcoded paths.
_sops-mkdir:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    if [[ ! -f "${SHARED}" ]]; then
        echo "Error: ${SHARED} not found. Run: just shared-generate <username>" >&2; exit 1
    fi
    # Extract all secret REL paths from shared.nix (values of nixos.* = "..." entries).
    mapfile -t RELS < <(grep -oP 'nixos\.[a-zA-Z0-9._-]+\s*=\s*"\K[^"]+' "${SHARED}")
    if [[ ${#RELS[@]} -eq 0 ]]; then
        echo "Error: no nixos.* secrets found in ${SHARED}" >&2; exit 1
    fi
    for REL in "${RELS[@]}"; do
        mkdir -p "{{SECRETS_PLAN_PATH}}/$(dirname "${REL}")"
        mkdir -p "{{SECRETS_CHIPR_PATH}}/$(dirname "${REL}")"
    done
    echo "Created dirs for ${#RELS[@]} secret(s) under secrets/plan and secrets/chipr"

_sops-keygen:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{SECRETS_KEYS_PATH}}"
    if [[ ! -f "{{SECRETS_KEYFILE}}" ]]; then
        age-keygen -o "{{SECRETS_KEYFILE}}" 2>/dev/null
        chmod 400 "{{SECRETS_KEYFILE}}"
        echo "Generated new age key at {{SECRETS_KEYFILE}}"
    else
        echo "Age key already exists at {{SECRETS_KEYFILE}}, skipping."
    fi

# Generate .sops.yaml from template (tmpl → sed → overwrite).
_sops-write-rules:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    if [[ ! -f "${SHARED}" ]]; then
        echo "Error: ${SHARED} not found. Run: just shared-generate <username>" >&2; exit 1
    fi
    U=$(grep -oP 'username\s*=\s*"\K[^"]+' "${SHARED}")
    if [[ -z "${U}" ]]; then
        echo "Error: could not parse username from ${SHARED}" >&2; exit 1
    fi
    PUB=$(age-keygen -y "{{SECRETS_KEYFILE}}")
    TMPL="{{SECRETS_TMPL_PATH}}/sops-rules.yaml.tmpl"
    DEST="{{DOT_SOPS_FILENAME}}"
    if [[ ! -f "${TMPL}" ]]; then
        echo "Error: sops rules template not found: ${TMPL}" >&2; exit 1
    fi
    sed \
        -e "s|__USERNAME__|${U}|g" \
        -e "s|__AGE_PUBLIC_KEY__|${PUB}|g" \
        "${TMPL}" > "${DEST}"
    echo "Written ${DEST} from template for '${U}'"


# ==============================================================================
# Private — plan plaintext instance generator
# ==============================================================================
# Generate one plaintext secret instance.
#
# Template path derivation rule (the single canonical rule for this file):
#   REL      = value of dotted key in shared.nix  (e.g. "nixos/.../kilig/password")
#   TMPL_REL = REL with real username reversed to __USERNAME__
#            = sed "s|/${U}/|/__USERNAME__/|g; s|redis-${U}|redis-__USERNAME__|g"
#   TMPL     = SECRETS_TMPL_PATH / TMPL_REL + ".yaml"
#
# This rule is the inverse of the substitution performed by shared-generate and
# is applied identically in _sops-chipr-write — ensuring plan and chipr always
# reference the same template file.
#
# Usage:   just _sops-plan-gen <dotted.key>
# Example: just _sops-plan-gen "nixos.core.srv.db.mongodb.user.password"
_sops-plan-gen key:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    U=$(grep -oP 'username\s*=\s*"\K[^"]+' "${SHARED}")
    pat=$(printf '%s' "{{key}}" | sed 's/\./\\./g')
    REL=$(grep -oP "${pat}"'\s*=\s*"\K[^"]+' "${SHARED}" || true)
    if [[ -z "${REL}" ]]; then
        echo "Error: key '{{key}}' not found in ${SHARED}" >&2; exit 1
    fi
    TMPL_REL=$(printf '%s' "${REL}" \
        | sed "s|/${U}/|/__USERNAME__/|g; s|redis-${U}|redis-__USERNAME__|g")
    TMPL="{{SECRETS_TMPL_PATH}}/${TMPL_REL}.yaml"
    DEST="{{SECRETS_PLAN_PATH}}/${REL}.yaml"
    if [[ ! -f "${TMPL}" ]]; then
        echo "Error: template not found: ${TMPL}" >&2; exit 1
    fi
    mkdir -p "$(dirname "${DEST}")"
    sed "s|__USERNAME__|${U}|g" "${TMPL}" > "${DEST}"
    echo "Generated plan: ${DEST}"


# ==============================================================================
# Private — chipr decrypt reader
# ==============================================================================
# Decrypt a secret by dotted key (path resolved at runtime from shared.nix).
# Usage:  just _sops-chipr-read "nixos.core.srv.db.mongodb.user.password"
_sops-chipr-read key:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    pat=$(printf '%s' "{{key}}" | sed 's/\./\\./g')
    REL=$(grep -oP "${pat}"'\s*=\s*"\K[^"]+' "${SHARED}" || true)
    if [[ -z "${REL}" ]]; then
        echo "Error: key '{{key}}' not found in ${SHARED}" >&2; exit 1
    fi
    sops decrypt "{{SECRETS_CHIPR_PATH}}/${REL}.yaml"


# ==============================================================================
# Private — generic chipr encrypt writer
# ==============================================================================
# Single implementation for all secret encryption. Eliminates per-secret duplication.
# Uses the same template path derivation rule as _sops-plan-gen.
#
# Usage:   just _sops-chipr-write <key> <prompt> <placeholder> [transform]
#   key:         dotted key in shared.nix — used to resolve REL and derive TMPL
#   prompt:      label shown before password entry (no trailing ": ")
#   placeholder: string in template YAML replaced by the secret value
#   transform:   "plain" (default) — store value as-is
#                "mkpasswd"        — hash via mkpasswd -m sha-512 before storing
#
# Execution flow:
#   1. Look up REL from shared.nix by dotted key
#   2. Derive TMPL_REL by reversing username substitution; locate TMPL file
#   3. Read secret interactively (hidden, confirmed); apply optional transform
#   4. sed substitute __USERNAME__ + placeholder in template
#   5. Pipe through sops encrypt → SECRETS_CHIPR_PATH/REL.yaml
#
# To add a new secret type: no changes here. Add to shared.nix.tmpl + template
# file + 4-line sops-chipr-create-* wrapper above.
_sops-chipr-write key prompt placeholder transform="plain":
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    U=$(grep -oP 'username\s*=\s*"\K[^"]+' "${SHARED}")

    # 1. Resolve REL path from shared.nix.
    pat=$(printf '%s' "{{key}}" | sed 's/\./\\./g')
    REL=$(grep -oP "${pat}"'\s*=\s*"\K[^"]+' "${SHARED}" || true)
    if [[ -z "${REL}" ]]; then
        echo "Error: key '{{key}}' not found in ${SHARED}" >&2; exit 1
    fi

    # 2. Derive template path (same rule as _sops-plan-gen — single definition).
    TMPL_REL=$(printf '%s' "${REL}" \
        | sed "s|/${U}/|/__USERNAME__/|g; s|redis-${U}|redis-__USERNAME__|g")
    TMPL="{{SECRETS_TMPL_PATH}}/${TMPL_REL}.yaml"
    DEST="{{SECRETS_CHIPR_PATH}}/${REL}.yaml"

    if [[ ! -f "${TMPL}" ]]; then
        echo "Error: template not found: ${TMPL}" >&2; exit 1
    fi

    # 3. Read secret interactively (hidden input, with confirmation).
    echo -n "{{prompt}}: "; read -rs secret; echo
    echo -n "Confirm: ";    read -rs csecret; echo
    if [[ "${secret}" != "${csecret}" ]]; then
        unset -v secret csecret
        echo "Error: confirmation mismatch" >&2; exit 1
    fi
    unset -v csecret

    # 4. Apply optional transform; clear plaintext immediately after.
    value="${secret}"
    unset -v secret
    if [[ "{{transform}}" == "mkpasswd" ]]; then
        value=$(printf '%s' "${value}" | mkpasswd -m sha-512 -R 5000 -s)
    fi

    # 5. Substitute __USERNAME__, then substitute the secret placeholder.
    #    awk via ENVIRON is used for the placeholder substitution instead of sed
    #    so that arbitrary characters in the secret value (|, \, &, newlines, …)
    #    are treated as literals and never interpreted as sed metacharacters.
    #    Atomic write: encrypt to a temp file first, then mv into place so that
    #    a sops failure never leaves the destination file truncated or corrupt.
    mkdir -p "$(dirname "${DEST}")"
    TMPOUT=$(mktemp "${DEST}.XXXXXX")
    export _SOPS_VAL="${value}"
    unset -v value
    sed "s|__USERNAME__|${U}|g" "${TMPL}" \
        | awk -v old="{{placeholder}}" '
            BEGIN { new = ENVIRON["_SOPS_VAL"] }
            {
                out = ""; s = $0
                while ((idx = index(s, old)) > 0) {
                    out = out substr(s, 1, idx-1) new
                    s = substr(s, idx+length(old))
                }
                print out s
            }' \
        | sops encrypt --input-type yaml --filename-override "${DEST}" /dev/stdin \
        > "${TMPOUT}"
    unset -v _SOPS_VAL
    mv -f "${TMPOUT}" "${DEST}"
    echo "OK: ${DEST}"
