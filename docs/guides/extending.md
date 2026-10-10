# 扩展指南 — 添加应用 / 语言环境 / Secret / 策略

> 本文是 README「扩展指南」节（T13.1 分层重构时从 README 原样迁出）。
> 落点速览（哪类改动去哪个目录）见 [README 目录结构](../../README.md#目录结构)。

### 添加应用

```bash
# GUI 应用
vim home/core/exp/app/<class>/<name>.nix
# 在 home/core/exp/app/<class>/default.nix 的 imports 中添加引用

# CLI 工具
vim home/core/exp/sys/<class>/<name>.nix
# 在 home/core/exp/sys/<class>/default.nix 的 imports 中添加引用
```

> `home/core/exp/app/<class>/default.nix` 的 imports 由 `shared.appCategories`
> map 路由——目录不在 app-set 的 `categories` 列表中的主机根本不会加载该类。

### 添加开发语言环境

```bash
mkdir home/env/dev/<lang>
# 参考 home/env/dev/python/ 的结构实现 default.nix
# pdshell 会自动发现并注册到 devShells.<arch>.<lang>
```

### 添加新 Secret（三步，核心逻辑零改动）

**Step 0** — `platform/nixos/core/srv/db/newdb.nix` impl + `platform/nixos/core/srv/db/default.nix` import

**Step 1** — `docs/tmpl/shared.nix.tmpl` 中添加：

```nix
nixos.core.srv.db.newdb.user.password = "nixos/core/srv/db/newdb/users/__USERNAME__/password";
```

**Step 2** — 创建 YAML 模板文件（YAML 叶子键名 = 路径最后一段）：

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

**Step 3** — `secrets.just` 的注册表加一行（`_secrets-registry`）：

```just
'newdb|nixos.core.srv.db.newdb.user.password|NewDB password|plain' \
```

使用即得：`just secret-set newdb` / `just secret-get newdb` / `just secrets-list`
（别名自动出现在表中）。`_secrets-mkdir`、路径解析、模板定位、加密逻辑 ——
**全部零改动**（注册表是唯一的别名→秘密映射）。

> **YAML 叶子键名约定**：sops-nix 按 `/` 分割 secret key 逐层查 YAML。
> 叶子键名必须与路径最后一段完全一致（`access-token` 单数），
> 值可以是 nix.conf 格式行（`access-tokens = github.com=TOKEN`）。

### 修改平台策略

```bash
vim docs/tmpl/shared.nix.tmpl  # 修改 platform / drive / window-manager 等
just shared-generate <username>  # 重新生成 shared.nix
```

### 修改用户名

用户名变更会导致所有 secret 路径失效（路径含用户名），需完整流程：

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

> 若希望复用旧 age key（跳过密钥销毁）：
>
> ```bash
> just secrets-plan-destroy && just rules-destroy   # 保留密文与 key
> just rules-init        # 用现有密钥重建 .sops.yaml
> just secrets-verify    # 既有 blob 直接收件人一致（无需重录）
> ```

### 添加新 AI CLI 工具

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
