# Extending Guide — Adding Apps / Language Environments / Secrets / Policies

> English mirror of [docs/guides/extending.md](../../guides/extending.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> This document is the README's "Extending Guide" section (moved out of the
> README verbatim during the T13.1 layered refactoring). For a quick overview
> of landing spots (which kind of change goes to which directory), see
> [the README's directory structure](../../../README.en.md#directory-structure).

### Adding an application

```bash
# GUI 应用
vim home/core/exp/app/<class>/<name>.nix
# 在 home/core/exp/app/<class>/default.nix 的 imports 中添加引用

# CLI 工具
vim home/core/exp/sys/<class>/<name>.nix
# 在 home/core/exp/sys/<class>/default.nix 的 imports 中添加引用
```

> The imports of `home/core/exp/app/<class>/default.nix` are routed by the
> `shared.appCategories` map — a host whose directory is not in the app-set's
> `categories` list never loads that class at all.

### Adding a development language environment

```bash
mkdir home/env/dev/<lang>
# 参考 home/env/dev/python/ 的结构实现 default.nix
# pdshell 会自动发现并注册到 devShells.<arch>.<lang>
```

### Adding a new secret (three steps, zero changes to core logic)

**Step 0** — `platform/nixos/system/core/srv/db/newdb.nix` impl + `platform/nixos/system/core/srv/db/default.nix` import

**Step 1** — add to `docs/tmpl/shared.nix.tmpl`:

```nix
nixos.core.srv.db.newdb.user.password = "nixos/core/srv/db/newdb/users/__USERNAME__/password";
```

**Step 2** — create the YAML template file (YAML leaf key name = the last segment of the path):

```yaml
# docs/tmpl/sops/nixos/core/srv/db/newdb/users/__USERNAME__/password.yaml
nixos:
  core:
    srv:
      db:
        newdb:
          users:
            __USERNAME__:
              password: "<YOUR_NEWDB_PASSWORD>"
```

**Step 3** — add one line to the registry in `secrets.just` (`_secrets-registry`):

```just
'newdb|nixos.core.srv.db.newdb.user.password|NewDB password|plain' \
```

Use it right away: `just secret-set newdb` / `just secret-get newdb` / `just
secrets-list` (the alias appears in the table automatically).
`_secrets-mkdir`, path resolution, template locating, encryption logic —
**all unchanged** (the registry is the only alias→secret mapping).

> **YAML leaf-key convention**: sops-nix splits the secret key on `/` and
> walks the YAML level by level. The leaf key name must exactly match the
> last segment of the path (`access-token`, singular); the value can be a
> nix.conf-format line (`access-tokens = github.com=TOKEN`).

### Modifying platform policies

```bash
vim docs/tmpl/shared.nix.tmpl  # 修改 platform / drive / window-manager 等
just shared-generate <username>  # 重新生成 shared.nix
```

### Changing the username

A username change invalidates all secret paths (the paths contain the
username), so the full procedure is required:

```bash
# 1. 重新生成 shared.nix
just shared-generate newname

# 2. 销毁旧 secret（旧路径已失效）⚠️ 不可逆，确保已备份
just secrets-destroy-all

# 3. 重新初始化 sops 基础设施
just secrets-init

# 4. 重新加密所有 secret（需重新输入）
just secret-set-all

# 5. 可选：重新生成明文模板参考
just secrets-plan-create
```

> If you prefer to reuse the old age key (skipping key destruction):
>
> ```bash
> just secrets-plan-destroy && just rules-destroy   # 保留密文与 key
> just rules-init        # 用现有密钥重建 .sops.yaml
> just secrets-verify    # 既有 blob 直接收件人一致（无需重录）
> ```

### Adding a new AI CLI tool

```bash
# 1. 创建工具模块
cat > home/core/exp/sys/ai/<tool-name>.nix << 'EOF'
{ inputs, shared, lib, config, pkgs, ... }:
{
  home.packages = with pkgs; [ <tool-package> ];
}
EOF

# 2. 在 home/core/exp/sys/ai/default.nix 的 imports 中添加引用
# 工具即刻在所有平台可用，无需额外配置
```

---
