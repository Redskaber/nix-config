# ==============================================================================
# commit.just — 数据驱动的提交规范部署（基于 commit-config flake input）
# ==============================================================================
# 依赖: nix, git, jq, 且 flake.nix 中已暴露 api.inputs 输出


# Deploy global commitlint rules and optional commitizen config to home
commit-global-rules:
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{ROOT}}
    CC_SRC="$(nix eval .#api.inputs --json --no-warn-dirty 2>/dev/null | jq -r '."commit-config"')"

    # commitlint global rules
    SRC="${CC_SRC}/commitlint.config.js"
    DEST="$HOME/.commitlintrc.js"
    rm -f "${DEST}"
    cp "${SRC}" "${DEST}"
    echo "✔ Global commitlint rules written to ${DEST}"

    # commitizen global config (optional)
    if [ -f "${CC_SRC}/.cz.toml" ]; then
        DEST_CZ="$HOME/.cz.toml"
        rm -f "${DEST_CZ}"
        cp "${CC_SRC}/.cz.toml" "${DEST_CZ}"
        echo "✔ Global commitizen config written to ${DEST_CZ}"
    fi


# Copy commitlint and commitizen configs to a project (self-contained)
commit-project-rules dir=".":
    #!/usr/bin/env bash
    set -euo pipefail
    TARGET_DIR="{{dir}}"
    cd {{ROOT}}
    CC_SRC="$(nix eval .#api.inputs --json --no-warn-dirty 2>/dev/null | jq -r '."commit-config"')"

    # commitlint rules
    RULE_SRC="${CC_SRC}/commitlint.config.js"
    DEST_RULE="${TARGET_DIR}/commitlint.config.js"
    rm -f "${DEST_RULE}"
    cp "${RULE_SRC}" "${DEST_RULE}"
    echo "✔ commitlint.config.js written to ${DEST_RULE}"

    # commitizen config (.cz.toml)
    CZ_SRC="${CC_SRC}/.cz.toml"
    if [ -f "${CZ_SRC}" ]; then
        DEST_CZ="${TARGET_DIR}/.cz.toml"
        rm -f "${DEST_CZ}"
        cp "${CZ_SRC}" "${DEST_CZ}"
        echo "✔ .cz.toml written to ${DEST_CZ}"
    fi


# Install husky hooks for a Git repo (no config files)
commit-husky-install dir=".":
    #!/usr/bin/env bash
    set -euo pipefail
    TARGET_DIR="{{dir}}"
    cd {{ROOT}}
    CC_SRC="$(nix eval .#api.inputs --json --no-warn-dirty 2>/dev/null | jq -r '."commit-config"')"
    HOOK_SRC="${CC_SRC}/husky/commit-msg"

    if [ ! -d "${TARGET_DIR}/.git" ]; then
        echo "Error: ${TARGET_DIR} is not a Git repository (no .git found)" >&2
        exit 1
    fi

    cd "${TARGET_DIR}"
    echo "→ Setting core.hooksPath to .husky"
    git config core.hooksPath .husky

    echo "→ Installing commit-msg hook from commit-config"
    mkdir -p .husky
    rm -f .husky/commit-msg
    cp "${HOOK_SRC}" .husky/commit-msg
    chmod +x .husky/commit-msg

    rm -f .husky/pre-commit

    echo "✔ Husky hooks installed for ${TARGET_DIR}"
    echo "ℹ  Commitlint will use the project's commitlint.config.js (or global ~/.commitlintrc.js)"


# Deploy rules + hooks for the nix-config repo
commit-setup:
    @just commit-project-rules "{{ROOT}}"
    @just commit-husky-install "{{ROOT}}"


