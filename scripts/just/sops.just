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
#   - Zero inline content: sops.just is pure orchestration; all YAML lives in templates
#   - Generate, don't mutate: tmpl → sed(placeholder) → overwrite, never in-place patch
#   - plan / chipr command sets fully separated — different lifecycle, different audience
#   - sops-init only sets up infrastructure (dirs + key + rules); no interactive prompts
#   - Destroy operations are granular to prevent accidental data loss
#
# Information source (all stages read from shared.nix — no env vars needed):
#   BOOTSTRAP     shared.nix must exist (just init writes it before calling sops-init)
#                 commands: sops-init, sops-rules-regen, _sops-mkdir, _sops-write-rules
#   POST-BOOTSTRAP paths from shared.nix secrets.* fields
#                 commands: sops-plan-create-all, sops-chipr-create-*, sops-chipr-read-*
#
# NOTE: imported by justfile; all paths use ROOT (defined in root justfile).
#
# Template directory layout: docs/tmpl/sops/
#   nixos/core/base/user/__USERNAME__/password.yaml
#   nixos/core/base/nix/users/__USERNAME__/github/access-token.yaml
#   nixos/core/srv/db/{mongodb,mysql,postgresql,redis}/users/…/password.yaml
#   sops-rules.yaml.tmpl  (.sops.yaml generation template)
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
# Paths come from shared.nix secrets.* fields (identical to chipr paths, different prefix).

# Generate all plaintext template instances from shared.nix.
sops-plan-create-all:
    @just _assert-shared
    @just _sops-plan-gen nixos/core/base/user/__USERNAME__/password.yaml                  "nixos.core.base.user.password"
    @just _sops-plan-gen nixos/core/base/nix/users/__USERNAME__/github/access-token.yaml  "nixos.core.base.nix.user.github.access-token"
    @just _sops-plan-gen nixos/core/srv/db/mongodb/users/__USERNAME__/password.yaml       "nixos.core.srv.db.mongodb.user.password"
    @just _sops-plan-gen nixos/core/srv/db/mysql/users/__USERNAME__/password.yaml         "nixos.core.srv.db.mysql.user.password"
    @just _sops-plan-gen nixos/core/srv/db/mysql/users/root/password.yaml                 "nixos.core.srv.db.mysql.root.password"
    @just _sops-plan-gen nixos/core/srv/db/postgresql/users/__USERNAME__/password.yaml    "nixos.core.srv.db.postgresql.user.password"
    @just _sops-plan-gen nixos/core/srv/db/redis/users/redis-__USERNAME__/password.yaml   "nixos.core.srv.db.redis.user.password"
    @echo "All plan instances created under {{SECRETS_PLAN_PATH}}"

# Delete all plaintext template instances.
sops-plan-destroy:
    @rm -rf {{SECRETS_PLAN_PATH}}
    @echo "Destroyed {{SECRETS_PLAN_PATH}}"


# ==============================================================================
# CIPHER LAYER — encrypt (POST-BOOTSTRAP, paths from shared.nix)
# ==============================================================================

# Encrypt user system password (mkpasswd sha-512).
sops-chipr-create-userpwd:
    @just _assert-shared
    @just _sops-chipr-userpwd

# Encrypt Nix/GitHub access token.
sops-chipr-create-nix:
    @just _assert-shared
    @just _sops-chipr-nix

# Encrypt MongoDB user password.
sops-chipr-create-mongodb:
    @just _assert-shared
    @just _sops-chipr-mongodb

# Encrypt MySQL root + user passwords.
sops-chipr-create-mysql:
    @just _assert-shared
    @just _sops-chipr-mysql

# Encrypt PostgreSQL user password.
sops-chipr-create-postgresql:
    @just _assert-shared
    @just _sops-chipr-postgresql

# Encrypt Redis user password.
sops-chipr-create-redis:
    @just _assert-shared
    @just _sops-chipr-redis

# Interactively encrypt all secrets in order.
sops-chipr-create-all:
    @just sops-chipr-create-userpwd
    @just sops-chipr-create-nix
    @just sops-chipr-create-mongodb
    @just sops-chipr-create-mysql
    @just sops-chipr-create-postgresql
    @just sops-chipr-create-redis


# ==============================================================================
# CIPHER LAYER — decrypt (POST-BOOTSTRAP, paths from shared.nix)
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
# Global destroy (granular, no USERNAME needed)
# ==============================================================================

# Destroy all sops artifacts: key + rules + all secrets (irreversible).
sops-destroy-all:
    @just sops-plan-destroy
    @just sops-chipr-destroy
    @just sops-rules-destroy
    @just sops-key-destroy
    @rm -rf {{SECRETS_PATH}}
    @echo "All sops artifacts destroyed."


# ==============================================================================
# Private — generic shared.nix value reader
# ==============================================================================
# Read any string value from shared.nix; whitespace-insensitive around `=`.
# Usage:  _shared-get <path> <dotted.key>
# Mechanism: escape `.` → `\.` in key, then match with \s*=\s*"\K pattern.
# Returns: matched value (no quotes); empty string if not found (caller checks).
_shared-get path key:
    #!/usr/bin/env bash
    set -euo pipefail
    pat=$(printf '%s' "{{key}}" | sed 's/\./\\./g')
    grep -oP "${pat}"'\s*=\s*"\K[^"]+' "{{path}}" || true


# ==============================================================================
# Private — dirs / key / rules (read from shared.nix)
# ==============================================================================

_sops-mkdir:
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
    for BASE in "{{SECRETS_PLAN_PATH}}/nixos/core" "{{SECRETS_CHIPR_PATH}}/nixos/core"; do
        mkdir -p \
            "${BASE}/base/nix/users/${U}/github" \
            "${BASE}/base/user/${U}" \
            "${BASE}/srv/db/mongodb/users/${U}" \
            "${BASE}/srv/db/mysql/users/${U}" \
            "${BASE}/srv/db/mysql/users/root" \
            "${BASE}/srv/db/postgresql/users/${U}" \
            "${BASE}/srv/db/redis/users/redis-${U}"
    done

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
# Private — plan plaintext instance generator (POST-BOOTSTRAP)
# ==============================================================================
# Generate one plaintext instance from a template.
# Usage:  just _sops-plan-gen <tmpl-relative-path> <shared-secret-key>
# Example: just _sops-plan-gen nixos/core/srv/db/mongodb/users/__USERNAME__/password.yaml \
#                               "nixos.core.srv.db.mongodb.user.password"
_sops-plan-gen tmpl key:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    U=$(grep -oP 'username\s*=\s*"\K[^"]+' "${SHARED}")
    pat=$(printf '%s' "{{key}}" | sed 's/\./\\./g')
    REL=$(grep -oP "${pat}"'\s*=\s*"\K[^"]+' "${SHARED}" || true)
    if [[ -z "${REL}" ]]; then
        echo "Error: key '{{key}}' not found in ${SHARED}" >&2; exit 1
    fi
    TMPL="{{SECRETS_TMPL_PATH}}/{{tmpl}}"
    DEST="{{SECRETS_PLAN_PATH}}/${REL}.yaml"
    if [[ ! -f "${TMPL}" ]]; then
        echo "Error: template not found: ${TMPL}" >&2; exit 1
    fi
    mkdir -p "$(dirname "${DEST}")"
    sed "s|__USERNAME__|${U}|g" "${TMPL}" > "${DEST}"
    echo "Generated plan: ${DEST}"


# ==============================================================================
# Private — chipr decrypt reader (POST-BOOTSTRAP)
# ==============================================================================
# Decrypt a secret identified by its shared.nix dotted key.
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
# Private — chipr interactive encrypt writers (POST-BOOTSTRAP)
# ==============================================================================

_sops-chipr-userpwd:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    U=$(grep -oP 'username\s*=\s*"\K[^"]+' "${SHARED}")
    REL=$(grep -oP 'nixos\.core\.base\.user\.password\s*=\s*"\K[^"]+' "${SHARED}")
    DEST="{{SECRETS_CHIPR_PATH}}/${REL}.yaml"
    mkdir -p "$(dirname "${DEST}")"
    echo -n "User system password: "; read -s pwd; echo
    echo -n "Confirm: ";              read -s cpwd; echo
    if [[ "${pwd}" != "${cpwd}" ]]; then
        unset -v pwd cpwd; echo "Error: mismatch" >&2; exit 1
    fi
    safe=$(printf '%s' "${pwd}" | mkpasswd -m sha-512 -R 5000 -s)
    unset -v pwd cpwd
    sed "s|__USERNAME__|${U}|g" "{{SECRETS_TMPL_PATH}}/nixos/core/base/user/__USERNAME__/password.yaml" \
        | sed "s|<YOUR_USER_PASSWORD_FROM_MKPASSWD>|${safe}|g" \
        | sops encrypt --input-type yaml --filename-override "${DEST}" /dev/stdin \
        > "${DEST}"
    unset -v safe
    echo "OK: ${DEST}"

_sops-chipr-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    U=$(grep -oP 'username\s*=\s*"\K[^"]+' "${SHARED}")
    REL=$(grep -oP 'nixos\.core\.base\.nix\.user\.github\.access-token\s*=\s*"\K[^"]+' "${SHARED}")
    DEST="{{SECRETS_CHIPR_PATH}}/${REL}.yaml"
    mkdir -p "$(dirname "${DEST}")"
    echo -n "GitHub access token: "; read -s tok; echo
    echo -n "Confirm: ";             read -s ctok; echo
    if [[ "${tok}" != "${ctok}" ]]; then
        unset -v tok ctok; echo "Error: mismatch" >&2; exit 1
    fi
    sed "s|__USERNAME__|${U}|g" "{{SECRETS_TMPL_PATH}}/nixos/core/base/nix/users/__USERNAME__/github/access-token.yaml" \
        | sed "s|<YOUR_GITHUB_TOKEN>|${tok}|g" \
        | sops encrypt --input-type yaml --filename-override "${DEST}" /dev/stdin \
        > "${DEST}"
    unset -v tok ctok
    echo "OK: ${DEST}"

_sops-chipr-mongodb:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    U=$(grep -oP 'username\s*=\s*"\K[^"]+' "${SHARED}")
    REL=$(grep -oP 'nixos\.core\.srv\.db\.mongodb\.user\.password\s*=\s*"\K[^"]+' "${SHARED}")
    DEST="{{SECRETS_CHIPR_PATH}}/${REL}.yaml"
    mkdir -p "$(dirname "${DEST}")"
    echo -n "MongoDB password: "; read -s pwd; echo
    echo -n "Confirm: ";          read -s cpwd; echo
    if [[ "${pwd}" != "${cpwd}" ]]; then
        unset -v pwd cpwd; echo "Error: mismatch" >&2; exit 1
    fi
    sed "s|__USERNAME__|${U}|g" "{{SECRETS_TMPL_PATH}}/nixos/core/srv/db/mongodb/users/__USERNAME__/password.yaml" \
        | sed "s|<YOUR_MONGODB_PASSWORD>|${pwd}|g" \
        | sops encrypt --input-type yaml --filename-override "${DEST}" /dev/stdin \
        > "${DEST}"
    unset -v pwd cpwd
    echo "OK: ${DEST}"

_sops-chipr-mysql:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    U=$(grep -oP 'username\s*=\s*"\K[^"]+' "${SHARED}")
    REL_ROOT=$(grep -oP 'nixos\.core\.srv\.db\.mysql\.root\.password\s*=\s*"\K[^"]+' "${SHARED}")
    REL_USER=$(grep -oP 'nixos\.core\.srv\.db\.mysql\.user\.password\s*=\s*"\K[^"]+' "${SHARED}")
    DEST_ROOT="{{SECRETS_CHIPR_PATH}}/${REL_ROOT}.yaml"
    DEST_USER="{{SECRETS_CHIPR_PATH}}/${REL_USER}.yaml"
    mkdir -p "$(dirname "${DEST_ROOT}")" "$(dirname "${DEST_USER}")"
    echo -n "MySQL root password: "; read -s rpwd;  echo
    echo -n "Confirm root: ";        read -s crpwd; echo
    echo -n "MySQL user password: "; read -s upwd;  echo
    echo -n "Confirm user: ";        read -s cupwd; echo
    if [[ "${rpwd}" != "${crpwd}" ]]; then
        unset -v rpwd crpwd upwd cupwd; echo "Error: root mismatch" >&2; exit 1
    fi
    if [[ "${upwd}" != "${cupwd}" ]]; then
        unset -v rpwd crpwd upwd cupwd; echo "Error: user mismatch" >&2; exit 1
    fi
    sed "s|<YOUR_MYSQL_ROOT_PASSWORD>|${rpwd}|g" "{{SECRETS_TMPL_PATH}}/nixos/core/srv/db/mysql/users/root/password.yaml" \
        | sops encrypt --input-type yaml --filename-override "${DEST_ROOT}" /dev/stdin \
        > "${DEST_ROOT}"
    sed "s|__USERNAME__|${U}|g" "{{SECRETS_TMPL_PATH}}/nixos/core/srv/db/mysql/users/__USERNAME__/password.yaml" \
        | sed "s|<YOUR_MYSQL_USER_PASSWORD>|${upwd}|g" \
        | sops encrypt --input-type yaml --filename-override "${DEST_USER}" /dev/stdin \
        > "${DEST_USER}"
    unset -v rpwd crpwd upwd cupwd
    echo "OK: mysql root + user"

_sops-chipr-postgresql:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    U=$(grep -oP 'username\s*=\s*"\K[^"]+' "${SHARED}")
    REL=$(grep -oP 'nixos\.core\.srv\.db\.postgresql\.user\.password\s*=\s*"\K[^"]+' "${SHARED}")
    DEST="{{SECRETS_CHIPR_PATH}}/${REL}.yaml"
    mkdir -p "$(dirname "${DEST}")"
    echo -n "PostgreSQL password: "; read -s pwd; echo
    echo -n "Confirm: ";             read -s cpwd; echo
    if [[ "${pwd}" != "${cpwd}" ]]; then
        unset -v pwd cpwd; echo "Error: mismatch" >&2; exit 1
    fi
    sed "s|__USERNAME__|${U}|g" "{{SECRETS_TMPL_PATH}}/nixos/core/srv/db/postgresql/users/__USERNAME__/password.yaml" \
        | sed "s|<YOUR_POSTGRESQL_PASSWORD>|${pwd}|g" \
        | sops encrypt --input-type yaml --filename-override "${DEST}" /dev/stdin \
        > "${DEST}"
    unset -v pwd cpwd
    echo "OK: ${DEST}"

_sops-chipr-redis:
    #!/usr/bin/env bash
    set -euo pipefail
    SHARED="{{SHARED_NIX_PATH}}"
    U=$(grep -oP 'username\s*=\s*"\K[^"]+' "${SHARED}")
    REL=$(grep -oP 'nixos\.core\.srv\.db\.redis\.user\.password\s*=\s*"\K[^"]+' "${SHARED}")
    DEST="{{SECRETS_CHIPR_PATH}}/${REL}.yaml"
    mkdir -p "$(dirname "${DEST}")"
    echo -n "Redis password: "; read -s pwd; echo
    echo -n "Confirm: ";        read -s cpwd; echo
    if [[ "${pwd}" != "${cpwd}" ]]; then
        unset -v pwd cpwd; echo "Error: mismatch" >&2; exit 1
    fi
    sed "s|__USERNAME__|${U}|g" "{{SECRETS_TMPL_PATH}}/nixos/core/srv/db/redis/users/redis-__USERNAME__/password.yaml" \
        | sed "s|<YOUR_REDIS_PASSWORD>|${pwd}|g" \
        | sops encrypt --input-type yaml --filename-override "${DEST}" /dev/stdin \
        > "${DEST}"
    unset -v pwd cpwd
    echo "OK: ${DEST}"
