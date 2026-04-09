set shell := [ "bash", "-c" ]

# ==============================================================================
# MainFlow
# ==============================================================================
# NixOS this config build entry.
init:
  @just nixos-init
  @just sops-init

# ==============================================================================
# Hardware
# ==============================================================================
# nixos-generate-config --root /mnt
# nixos-generate-config --show-hardware-config
NIXOS_HARDWARE_PATH := "./nixos/core/base/hardware.nix"
# Create nixos generate config for user custom.(only first build need, base ['/' 'boot' 'swap'])
nixos-init:
  @nixos-generate-config --show-hardware-config >> {{NIXOS_HARDWARE_PATH}}


# ==============================================================================
# devenv
# ==============================================================================
DEV_PROFILE_HOME := "$HOME/.local/state/nix/profiles/dev"

# Create all development environments (including combined environments).
devenv-create-all:
  @just devenv-create       c
  @just devenv-create       cpp
  @just devenv-create       go
  @just devenv-create       java
  @just devenv-create       javascript
  @just devenv-create       lisp
  @just devenv-create       lua
  @just devenv-create       nix
  @just devenv-create-from  nix derivation-free
  @just devenv-create-from  nix derivation-unfree
  @just devenv-create-from  nix derivation-free-security
  @just devenv-create       python
  @just devenv-create-from  python renpy
  @just devenv-create       re
  @just devenv-create       rust
  @just devenv-create       typescript
  @just devenv-create       zig
  @just devenv-create       default

# Create a specified locale (e.g., just devenv-create rust).
devenv-create lang:
  @mkdir -p                      {{DEV_PROFILE_HOME}}/{{lang}}
  @nix develop                   .#{{lang}}  --profile {{DEV_PROFILE_HOME}}/{{lang}}/kilig-{{lang}}

# Create a compound environment (e.g., just devenv-create-from python renpy).
devenv-create-from lang class:
  @mkdir -p                      {{DEV_PROFILE_HOME}}/{{lang}}
  @nix develop                   .#{{lang}}-{{class}}  --profile {{DEV_PROFILE_HOME}}/{{lang}}/kilig-{{lang}}-{{class}}

# Clear all environment configuration directories.
devenv-delete-all:
  @rm -rf                        {{DEV_PROFILE_HOME}}/*

# Delete the specified locale directory.
devenv-delete lang:
  @rm -rf                        {{DEV_PROFILE_HOME}}/{{lang}}

# Delete the profile for the composite environment (keeping the parent directory).
devenv-delete-from lang class:
  @rm -rf                        {{DEV_PROFILE_HOME}}/{{lang}}/kilig-{{lang}}-{{class}}*

# Delete and then rebuild once environments (force refresh).
devenv-update lang:
  @just devenv-delete {{lang}}
  @just devenv-create {{lang}}

# Delete and then rebuild once from cls environments (force refresh).
devenv-update-from lang class:
  @just devenv-delete-from {{lang}} {{class}}
  @just devenv-create-from {{lang}} {{class}}

# Delete and then rebuild all environments (force refresh).
devenv-update-all:
  @just dev-delete-all
  @just dev-create-all

# Display the output of all devShells in Flake.
devenv-show:
  @nix flake show | grep devShells -A21

# The created environment configurations are listed in a tree structure.
devenv-list:
  @eza --tree                    {{DEV_PROFILE_HOME}}

# Enter an existing profile environment (without creating a persistent profile).
devenv-use lang:
  @nix develop                   .#{{lang}}  --profile {{DEV_PROFILE_HOME}}/{{lang}}/kilig-{{lang}}

# Enter an existing composite profile environment (without creating a persistent profile).
devenv-use-from lang class:
  @nix develop                   .#{{lang}}-{{class}}  --profile {{DEV_PROFILE_HOME}}/{{lang}}/kilig-{{lang}}-{{class}}



# ==============================================================================
# sops (age)
# ==============================================================================
SECRETS_PATH        :=                      "secrets"
SECRETS_CHIPR_PATH  := SECRETS_PATH       / "chipr"
SECRETS_PLAN_PATH   := SECRETS_PATH       / "plan"
DOT_SOPS_FILENAME   :=                      ".sops.yaml"
SECRETS_KEYS_PATH   :=                      "$HOME/.config/sops/age"
SECRETS_KEYFILENAME := SECRETS_KEYS_PATH  / "keys.txt"


# Initialize sops environment: generate keys, create config, and prepare secret files.
sops-init:
  @just _sops-create-secrets-structs
  @just _sops-create-agekeygen-file
  @just _sops-create-dotsopsfile
  @just _sops-create-secrets-plan-base-userpwd
  @just _sops-create-secrets-plan-base-nix
  @just _sops-create-secrets-plan-db-mongodb
  @just _sops-create-secrets-plan-db-mysql
  @just _sops-create-secrets-plan-db-postgresql
  @just _sops-create-secrets-plan-db-redis
  @just _sops-create-secrets-chipr-base-userpwd
  @just _sops-create-secrets-chipr-base-nix
  @just _sops-create-secrets-chipr-db-mongodb
  @just _sops-create-secrets-chipr-db-mysql
  @just _sops-create-secrets-chipr-db-postgresql
  @just _sops-create-secrets-chipr-db-redis

# Display the public key associated with the generated age identity.
sops-read-pubkey:
  @age-keygen -y {{SECRETS_KEYFILENAME}}

# Decrypt and display the user password secret.
sops-decrypt-user:
  @just _sops-decrypt-secrets-chipr-base-userpwd

# Decrypt and display the Nix/GitHub visited token secret.
sops-decrypt-visited:
  @just _sops-decrypt-secrets-chipr-base-nix

# Decrypt and display the MongoDB user secret.
sops-decrypt-mongodb:
  @just _sops-decrypt-secrets-chipr-db-mongodb

# Decrypt and display the MySQL user secret.
sops-decrypt-mysql:
  @just _sops-decrypt-secrets-chipr-db-mysql

# Decrypt and display the PostgreSQL user secret.
sops-decrypt-postgresql:
  @just _sops-decrypt-secrets-chipr-db-postgresql

# Decrypt and display the Redis user secret.
sops-decrypt-redis:
  @just _sops-decrypt-secrets-chipr-db-redis

# Remove the generated age identity key file.
sops-destory-keys:
  @just _sops-delete-agekeygen-file

# Remove the secret directory structure (plans and chipr).
sops-destory-structs:
  @just _sops-delete-secrets-structs

# Completely remove all sops configurations, keys, and secret files.
sops-destory:
  @just _sops-delete-secrets-structs
  @just _sops-delete-agekeygen-file
  @rm -rf {{SECRETS_PATH}}


_sops-create-secrets-structs:
  @mkdir -p      {{SECRETS_PLAN_PATH}}/nixos/core/{base/{nix,users}/kilig,srv/db/{mongodb,mysql,postgresql}/users/kilig,srv/db/mysql/users/root,srv/db/redis/users/redis-kilig}
  @mkdir -p      {{SECRETS_CHIPR_PATH}}/nixos/core/{base/{nix,users}/kilig,srv/db/{mongodb,mysql,postgresql}/users/kilig,srv/db/mysql/users/root,srv/db/redis/users/redis-kilig}

_sops-delete-secrets-structs:
  @rm    -rf     {{SECRETS_PLAN_PATH}}
  @rm    -rf     {{SECRETS_CHIPR_PATH}}

_sops-create-agekeygen-file:
  @mkdir -p      {{SECRETS_KEYS_PATH}}
  @age-keygen -o {{SECRETS_KEYFILENAME}} 2>/dev/null || true
  @chmod  400    {{SECRETS_KEYFILENAME}}

_sops-delete-agekeygen-file:
  @rm    -rf     {{SECRETS_KEYS_PATH}}

_sops-create-dotsopsfile:
  #!/usr/bin/env bash
  set -euo pipefail
  PUBLIC_KEY=$(age-keygen -y {{SECRETS_KEYFILENAME}})
  cat > {{DOT_SOPS_FILENAME}} <<'EOF'
  keys:
  - &age_kilig_publish_key PLACEHOLDER_PUBLIC_KEY
  creation_rules:
  - path_regex: {{SECRETS_PATH}}/chipr/nixos/core/base/users/kilig/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
        - *age_kilig_publish_key
  - path_regex: {{SECRETS_PATH}}/chipr/nixos/core/base/nix/kilig/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
        - *age_kilig_publish_key
  - path_regex: {{SECRETS_PATH}}/chipr/nixos/core/srv/db/mongodb/users/kilig/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
        - *age_kilig_publish_key
  - path_regex: {{SECRETS_PATH}}/chipr/nixos/core/srv/db/mysql/users/kilig/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
        - *age_kilig_publish_key
  - path_regex: {{SECRETS_PATH}}/chipr/nixos/core/srv/db/mysql/users/root/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
        - *age_kilig_publish_key
  - path_regex: {{SECRETS_PATH}}/chipr/nixos/core/srv/db/postgresql/users/kilig/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
        - *age_kilig_publish_key
  - path_regex: {{SECRETS_PATH}}/chipr/nixos/core/srv/db/redis/users/redis-kilig/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
        - *age_kilig_publish_key
  EOF
  sed -i.bak "s|PLACEHOLDER_PUBLIC_KEY|${PUBLIC_KEY}|g" {{DOT_SOPS_FILENAME}} && \
    rm -f {{DOT_SOPS_FILENAME}}.bak

_sops-delete-dotsopsfile:
  rm -rf {{DOT_SOPS_FILENAME}}

_sops-create-secrets-plan-base-userpwd:
  #!/usr/bin/env bash
  set -euo pipefail
  cat > {{SECRETS_PLAN_PATH}}/nixos/core/base/users/kilig/password.yaml << 'EOF'
  nixos:
    core:
      base:
        users:
          kilig:
            password: "<YOUR_USER_PASSWORD_FROM_MKPASSWD>"
  EOF

_sops-create-secrets-plan-base-nix:
  #!/usr/bin/env bash
  set -euo pipefail
  cat > {{SECRETS_PLAN_PATH}}/nixos/core/base/nix/kilig/nixos-github-git-visited.yaml << 'EOF'
  nixos:
    core:
      base:
        nix:
          kilig:
            nixos-github-git-visited: "access-tokens = github.com=<YOUR_GITHUB_VISITED_TOKEN>"
  EOF

_sops-create-secrets-plan-db-mongodb:
  #!/usr/bin/env bash
  set -euo pipefail
  cat > {{SECRETS_PLAN_PATH}}/nixos/core/srv/db/mongodb/users/kilig/password.yaml << 'EOF'
  nixos:
    core:
      srv:
        db:
          mongodb:
            users:
              kilig:
                password: "<YOUR_MONGODB_USER_PASSWORD>"
  EOF

_sops-create-secrets-plan-db-mysql:
  #!/usr/bin/env bash
  set -euo pipefail
  cat > {{SECRETS_PLAN_PATH}}/nixos/core/srv/db/mysql/users/kilig/password.yaml << 'EOF'
  nixos:
    core:
      srv:
        db:
          mysql:
            users:
              kilig:
                password: "<YOUR_MYSQL_USER_PASSWORD>"
  EOF
  cat > {{SECRETS_PLAN_PATH}}/nixos/core/srv/db/mysql/users/root/password.yaml << 'EOF'
  nixos:
    core:
      srv:
        db:
          mysql:
            users:
              root:
                password: "<YOUR_MYSQL_ROOT_PASSWORD>"
  EOF

_sops-create-secrets-plan-db-postgresql:
  #!/usr/bin/env bash
  set -euo pipefail
  cat > {{SECRETS_PLAN_PATH}}/nixos/core/srv/db/postgresql/users/kilig/password.yaml << 'EOF'
  nixos:
    core:
      srv:
        db:
          postgresql:
            users:
              kilig:
                password: "<YOUR_POSTGRESQL_USER_PASSWORD>"
  EOF

_sops-create-secrets-plan-db-redis:
  #!/usr/bin/env bash
  set -euo pipefail
  cat > {{SECRETS_PLAN_PATH}}/nixos/core/srv/db/redis/users/redis-kilig/password.yaml << 'EOF'
  nixos:
    core:
      srv:
        db:
          redis:
            users:
              redis-kilig:
                password: "<YOUR_REDIS_USER_PASSWORD>"
  EOF

_sops-create-secrets-chipr-base-userpwd:
  #!/usr/bin/env bash
  set -euo pipefail
  echo -n "Please input user password: "
  read -s user_pwd
  echo
  echo -n "Confirm password: "
  read -s confirm_pwd
  echo
  if [[ "${user_pwd}" != "${confirm_pwd}" ]]; then
    unset -v user_pwd confirm_pwd 2>/dev/null || true
    echo "Error: passwords do not match" 2>/dev/null || true
    exit 1
  fi
  safe_pwd=$(printf '%s' "$user_pwd" | mkpasswd -m sha-512 -R 5000 -s)
  unset -v user_pwd confirm_pwd
  cat << EOF              \
    | sops encrypt        \
    --input-type yaml     \
    --filename-override   \
    {{SECRETS_CHIPR_PATH}}/nixos/core/base/users/kilig/password.yaml  \
    > {{SECRETS_CHIPR_PATH}}/nixos/core/base/users/kilig/password.yaml
  nixos:
    core:
      base:
        users:
          kilig:
            password: "${safe_pwd}"
  EOF
  unset -v safe_pwd
  echo "Successfully created and encryted {{SECRETS_CHIPR_PATH}}/nixos/core/base/users/kilig/password.yaml"

_sops-create-secrets-chipr-base-nix:
  #!/usr/bin/env bash
  set -euo pipefail
  echo -n "Please input your nix visited github token: "
  read -s nvg_token
  echo
  echo -n "Confirm token: "
  read -s confirm_nvg_token
  echo
  if [[ "${nvg_token}" != "${confirm_nvg_token}" ]]; then
    unset -v nvg_token confirm_nvg_token 2>/dev/null || true
    echo "Error: github tokens do not match" 2>/dev/null || true
    exit 1
  fi
  cat << EOF              \
    | sops encrypt        \
    --input-type yaml     \
    --filename-override   \
    {{SECRETS_CHIPR_PATH}}/nixos/core/base/nix/kilig/nixos-github-git-visited.yaml  \
    > {{SECRETS_CHIPR_PATH}}/nixos/core/base/nix/kilig/nixos-github-git-visited.yaml
  nixos:
    core:
      base:
        nix:
          kilig:
            nixos-github-git-visited: "access-tokens = github.com=${nvg_token}"
  EOF
  unset -v nvg_token confirm_nvg_token
  echo "Successfully created and encryted {{SECRETS_CHIPR_PATH}}/nixos/core/base/nix/kilig/nixos-github-git-visited.yaml"

_sops-create-secrets-chipr-db-mongodb:
  #!/usr/bin/env bash
  set -euo pipefail
  echo -n "Please input user mongodb password: "
  read -s user_pwd
  echo
  echo -n "Confirm password: "
  read -s confirm_pwd
  echo
  if [[ "${user_pwd}" != "${confirm_pwd}" ]]; then
    unset -v user_pwd confirm_pwd 2>/dev/null || true
    echo "Error: mongodb passwords do not match" 2>/dev/null || true
    exit 1
  fi
  cat << EOF              \
    | sops encrypt        \
    --input-type yaml     \
    --filename-override   \
    {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/mongodb/users/kilig/password.yaml  \
    > {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/mongodb/users/kilig/password.yaml
  nixos:
    core:
      srv:
        db:
          mongodb:
            users:
              kilig:
                password: "${user_pwd}"
  EOF
  unset -v user_pwd confirm_pwd
  echo "Successfully created and encryted {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/mongodb/users/kilig/password.yaml"

_sops-create-secrets-chipr-db-mysql:
  #!/usr/bin/env bash
  set -euo pipefail
  echo -n "Please input mysql root password: "
  read -s root_pwd
  echo
  echo -n "Confirm root password: "
  read -s confirm_root_pwd
  echo
  echo -n "Please input mysql user password: "
  read -s user_pwd
  echo
  echo -n "Confirm user password: "
  read -s confirm_user_pwd
  echo
  if [[ "${root_pwd}" != "${confirm_root_pwd}" ]]; then
    unset -v root_pwd confirm_root_pwd 2>/dev/null || true
    echo "Error: mysql root passwords do not match" 2>/dev/null || true
    exit 1
  fi
  if [[ "${user_pwd}" != "${confirm_user_pwd}" ]]; then
    unset -v user_pwd confirm_user_pwd 2>/dev/null || true
    echo "Error: mysql user passwords do not match" 2>/dev/null || true
    exit 1
  fi
  cat << EOF              \
    | sops encrypt        \
    --input-type yaml     \
    --filename-override   \
    {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/mysql/users/root/password.yaml  \
    > {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/mysql/users/root/password.yaml
  nixos:
    core:
      srv:
        db:
          mysql:
            users:
              root:
                password: "${root_pwd}"
  EOF
  cat << EOF              \
    | sops encrypt        \
    --input-type yaml     \
    --filename-override   \
    {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/mysql/users/kilig/password.yaml  \
    > {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/mysql/users/kilig/password.yaml
  nixos:
    core:
      srv:
        db:
          mysql:
            users:
              kilig:
                password: "${user_pwd}"
  EOF
  unset -v root_pwd confirm_root_pwd
  unset -v user_pwd confirm_user_pwd
  echo "Successfully created and encryted {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/mysql/users/root/password.yaml"
  echo "Successfully created and encryted {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/mysql/users/kilig/password.yaml"

_sops-create-secrets-chipr-db-postgresql:
  #!/usr/bin/env bash
  set -euo pipefail
  echo -n "Please input postgresql user password: "
  read -s user_pwd
  echo
  echo -n "Confirm password: "
  read -s confirm_pwd
  echo
  if [[ "${user_pwd}" != "${confirm_pwd}" ]]; then
    unset -v user_pwd confirm_pwd 2>/dev/null || true
    echo "Error: postgresql passwords do not match" 2>/dev/null || true
    exit 1
  fi
  cat << EOF              \
    | sops encrypt        \
    --input-type yaml     \
    --filename-override   \
    {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/postgresql/users/kilig/password.yaml  \
    > {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/postgresql/users/kilig/password.yaml
  nixos:
    core:
      srv:
        db:
          postgresql:
            users:
              kilig:
                password: "${user_pwd}"
  EOF
  unset -v user_pwd confirm_pwd
  echo "Successfully created and encryted {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/postgresql/users/kilig/password.yaml"

_sops-create-secrets-chipr-db-redis:
  #!/usr/bin/env bash
  set -euo pipefail
  echo -n "Please input redis user password: "
  read -s user_pwd
  echo
  echo -n "Confirm password: "
  read -s confirm_pwd
  echo
  if [[ "${user_pwd}" != "${confirm_pwd}" ]]; then
    unset -v user_pwd confirm_pwd 2>/dev/null || true
    echo "Error: redis passwords do not match" 2>/dev/null || true
    exit 1
  fi
  cat << EOF              \
    | sops encrypt        \
    --input-type yaml     \
    --filename-override   \
    {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/redis/users/redis-kilig/password.yaml  \
    > {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/redis/users/redis-kilig/password.yaml
  nixos:
    core:
      srv:
        db:
          redis:
            users:
              redis-kilig:
                password: "${user_pwd}"
  EOF
  unset -v user_pwd confirm_pwd
  echo "Successfully created and encryted {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/redis/users/redis-kilig/password.yaml"

_sops-decrypt-secrets-chipr-base-userpwd:
  #!/usr/bin/env bash
  set -euo pipefail
  sops decrypt {{SECRETS_CHIPR_PATH}}/nixos/core/base/users/kilig/password.yaml

_sops-decrypt-secrets-chipr-base-nix:
  #!/usr/bin/env bash
  set -euo pipefail
  sops decrypt {{SECRETS_CHIPR_PATH}}/nixos/core/base/nix/kilig/nixos-github-git-visited.yaml

_sops-decrypt-secrets-chipr-db-mongodb:
  #!/usr/bin/env bash
  set -euo pipefail
  sops decrypt {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/mongodb/users/kilig/password.yaml

_sops-decrypt-secrets-chipr-db-mysql:
  #!/usr/bin/env bash
  set -euo pipefail
  sops decrypt {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/mysql/users/root/password.yaml
  sops decrypt {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/mysql/users/kilig/password.yaml

_sops-decrypt-secrets-chipr-db-postgresql:
  #!/usr/bin/env bash
  set -euo pipefail
  sops decrypt {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/postgresql/users/kilig/password.yaml

_sops-decrypt-secrets-chipr-db-redis:
  #!/usr/bin/env bash
  set -euo pipefail
  sops decrypt {{SECRETS_CHIPR_PATH}}/nixos/core/srv/db/redis/users/redis-kilig/password.yaml


