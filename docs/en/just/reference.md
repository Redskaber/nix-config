# Complete just command reference — 98 recipes × 14 groups

> English mirror of [docs/just/reference.md](../../just/reference.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> This document is the full version of the README's "justfile command reference"
> section (migrated verbatim out of the README during the T13.1 layered refactor).
> `just --list` gives the same-source entry points in the terminal; for the daily
> quick reference (the three high-frequency groups deploy / devenv / secrets) see
> the [README](../../../README.en.md#daily-operations-quick-reference).

> The full verb surface has 98 recipes, annotated `[group]` into 14 groups
> (bootstrap / cachix / commit / deploy / devenv / disk / flake / hardware / keys /
> maintenance / rules / secrets / services / shared) — `just --list` gives every
> entry point organized by group; bare `just` (no arguments) prints the start-here
> map; the secrets-side lifecycle map is entered from `just secrets-guide`.
> Introspection: `just <recipe> --evaluate` prints any recipe's variable
> evaluation and its expanded command body (without executing) — a self-service
> troubleshooting surface for interactive workflows.
>
> Description convention (R28): `just --list` displays the **last consecutive `#`
> comment line** above the recipe — that line must be a complete, concise,
> self-contained single sentence (examples and supplementary notes go above it,
> never as the final line).

### Global (bootstrap entry points)

```bash
# 完整初始化（新机器）—— <username> 是唯一必须提供的参数：
#   1. docs/tmpl/shared.nix.tmpl → shared.nix（策略真值）
#   2. 生成 hosts/<hostname>/hardware.nix（当前硬件探测）
#   3. 初始化 sops：目录 + user age 密钥 + .sops.yaml 规则基线
just init <username>

# 服务器机直达双 key（host 密钥材料先行时，状态机跳一跳）：
#   先生成 host keypair（仓外交付副本），再把公钥传入引导：
just key-new-host <alias>            # 生成 keypair，打印公钥
just init <username> <alias> <age1…> # EMPTY → USER+HOST 直达

# own host = srv host（个人机同时跑 srv 服务）——host 私钥落位本机：
just key-install-host <alias>        # identity 合并进本机 sops key 文件
# （硬化 srv 策略后本机仍可解；交付副本此时可 shred）

# POST-BOOTSTRAP（shared.nix 已存在）
just secrets-init [alias age1…]    # 仅初始化 sops 基础设施（可选直达双 key）
just secrets-plan-create           # 生成明文模板参考
just rules-init                    # 仅当 .sops.yaml 缺失时重建（对已演化文件拒绝）
```

### deploy — hosts & deployment targets (T2.4, data-driven)

> The host inventory is enumerated from the hosts/ directory and auto-discovered
> by the flake — adding a machine = `mkdir hosts/<name>`
>
> - Two files, zero flake changes; the recipes here are likewise zero-hardcoded.

```bash
just hosts-list                 # 列出全部可求值主机（nixosConfigurations 键）
just home-targets               # 列出全部独立 home-manager 目标（<user>@<host>）

just nixos-switch <host>        # NixOS 切换（= sudo nixos-rebuild switch --flake .#<host>）
just nixos-test <host>          # test 模式（不写 boot 条目，重启即弃）
just nixos-boot <host>          # boot 模式（T10.2：只设下一代引导，不激活——重启才生效）
just home-switch <host>         # HM 切换（读 shared.nix 用户名 → <user>@<host>）

# colmena 远程部署面（T20.1）——同一模块树同一策略 IR，CI 锁发射等价：
just deploy-list                # 列出 colmena 部署面（= nixosHosts；darwin/HM 走自己的动词）
just deploy <host>              # 远程部署：构建→上传→激活（ssh，策略用户；CLI 钉 v0.5.0）
just deploy-local               # 本机部署（apply-local --sudo；需 hosts/<h>/deploy.nix 开关）
# 例: just nixos-switch nixos / just home-switch wsl / just deploy nixos
```

### shared — policy-layer generation

```bash
just shared-generate <username>  # 从模板生成 shared.nix（唯一合法写入方式）
just shared-show-username        # 显示当前 shared.nix 中的用户名（诊断）
just shared-validate             # 验证模板占位符存在
just shared-roundtrip            # 验证 shared.nix ⇄ 模板可双向字节一致再生（门禁同源）
```

### hardware — hardware configuration

```bash
just hardware-migrate         # 一键迁移：hardware.nix → facter.json（T19.1；探测报告 + 挂载/kernelModules
                               # 原样搬入主机入口 + 翻转接线 + 退役 legacy 文件；终态由事实源普查锁定）
just hardware-facter           # 生成 hosts/<hostname>/facter.json（声明式路线，T5.12；首次或硬件变更后）
just hardware-generate         # 生成 hosts/<hostname>/hardware.nix（legacy 路线，nixos-generate-config）
just hardware-show             # 显示当前 hardware.nix 内容
just hardware-list             # 列出所有已配置主机
just sound-audit               # 只读：采集本机音频形态证据（债 #9 语义半部，T17.1）——
                               # 按运行时事实探测形态（WSL / 虚机 / 裸金属），打印匹配的
                               # 裁决矩阵行与建议翻转（卷宗 docs/guides/sound-adjudication.md）
```

### disk — disk-layout application + state-policy inspection (T5.13 + T5.14)

```bash
just disk-show <host>          # 只读：求值该主机 disko 布局的推导结果（fileSystems/boot 接线）
just persist-show <host>       # 只读：该主机的状态契约（生存清单 + ephemeral-root 回滚配方）
just disk-format <host>        # 破坏性：从锁定闭包构建并运行 pinned 分区/格式化/挂载脚本
                               # （重装/installer 场景；extra args 透传，如 --dry-run）
```

### services — on-demand service management

```bash
# 立即启动/停止（不持久，重启后失效）
just service-start <name>        # systemctl start
just service-stop <name>         # systemctl stop
just service-restart <name>      # systemctl restart
just service-status <name>       # systemctl status

# 开机自启管理（持久，跨重启 + 跨 rebuild）
just service-enable <name>       # systemctl enable（重启后自启）
just service-disable <name>      # systemctl disable（重启后不自启）
just service-is-enabled <name>   # 检查是否开机自启

# 数据库别名
just db-start <name>             # = service-start
just db-stop <name>              # = service-stop
just db-enable <name>            # = service-enable
just db-disable <name>           # = service-disable
just db-list                     # 列出所有数据库服务
just autostart-list              # 列出所有已启用的服务
```

### flake — dependency management

```bash
just flake-update-all            # 更新所有 inputs
just flake-update <pkg>          # 更新单个 input
just flake-update-not-sops       # 更新除 sops-nix 外的所有 inputs（sops-nix 版本锁定）
just flake-update-configs        # 仅更新 *-config inputs（外部配置仓库）
just flake-update-dry            # dry-run：预览会变更哪些 inputs（不修改 flake.lock）
just flake-show                  # 显示所有 flake 输出（含 devShells）
just flake-lock-show             # 显示当前锁定版本（只读）
```

### devenv — development environments

```bash
just devenv-create rust                     # 创建单语言 profile（离线可用）
just devenv-create-from python renpy        # 创建复合变体 profile
just devenv-use rust                        # 进入已有单语言环境
just devenv-use-from python machine         # 进入已有复合变体环境
just devenv-update rust                     # 强制重建单语言环境
just devenv-update-from python machine      # 强制重建复合变体环境
just devenv-delete rust                     # 删除单语言 profile
just devenv-delete-from python renpy        # 删除复合变体 profile
just devenv-create-all                      # 创建所有已知环境（含复合变体）
just devenv-delete-all                      # 删除所有 profile（强制重建用）
just devenv-update-all                      # 删除并重建所有环境
just devenv-show                            # 列出 flake 中所有可用 devShell
just devenv-list                            # 树状显示已创建 profile
```

**Profile naming rule:** `<username>-<lang>[-<class>]`, stored under
`~/.local/state/nix/profiles/dev/<lang>/`.

### secrets — keys & encryption (three objects × lifecycle verbs, registry-driven)

> The entry point is `just secrets-guide` (state machine + verb matrix + scenario
> flows); `just secrets-list` answers "which secrets exist, which is missing" at
> any time.
> The template `docs/tmpl/sops/sops-rules.yaml.tmpl` carries a dual rendering
> mode: the user key row renders unconditionally, while the host key row (marked
> `# __HOST__`) is decided by the bootstrap invocation.
> The repository carries the **maintainer's** ciphertext (undecryptable by you) —
> the fork-takeover procedure is in
> [docs/architecture/mechanisms.md §5 security layer](../architecture/mechanisms.md#5-security-layer--sops--age-layered-management).

```bash
# ── 引导（BOOTSTRAP，需要先 just shared-generate <username>）────────────
just secrets-guide                # 生命周期地图：状态机/动词矩阵/情景流（从这里开始）
just secrets-init                 # 目录 + user 密钥 + 规则基线（USER_ONLY）
just secrets-init <alias> <age1…> # 直达双 key（EMPTY → USER+HOST，host 行渲染）
just secrets-init-with-plan       # 同 secrets-init + 生成所有明文模板实例

# ── secrets：秘密值（REGISTRY 驱动，别名 → shared.nix dotted key）─────────
just secrets-list                 # 别名表 × 域 × 加密状态（缺什么一目了然）
just secret-set <alias>           # 交互式加密一个秘密（upsert，输入即加密）
just secret-set-all               # 按注册表顺序录入全部秘密
just secret-get <alias>           # 解密并打印
just secret-edit <alias>          # 解密进 $EDITOR，保存即重新加密
just secret-remove <alias>        # 删除单个密文 blob（提示配置层声明）
# 别名: userpwd · nix · mongodb · mysql · mysql-root · postgresql · redis

# ── registry：注册表 CRUD（R27，数据驱动三层一次写全）─────────────────
just secrets-add <alias> <rel-path> [prompt] [transform]
                                  # 注册新秘密：registry.toml 行 + 模板骨架 +
                                  #   shared.nix/tmpl 声明，一条命令三层齐
                                  #   （cachix-token 例：见下方 cachix 组）
just secrets-edit <alias> [prompt] [transform]
                                  # 改注册行的提示语 / 变换（plain|mkpasswd）
just secrets-remove <alias>       # 退役秘密（拒绝在密文仍在时执行——先 secret-remove）
just secrets-show <alias>         # 单个秘密全档案（行/路径/规则/收件人，不解密）
just secrets-declared             # shared.nix 声明 ↔ 注册表漂移视图（谁没被动词覆盖）
just secrets-db                   # 数据库缓存状态（行/声明/密文计数 + 指纹）
just secrets-db-sync              # 强制重建缓存（手改 registry.toml / shared.nix 后）

# ── keys：谁能解密（KEY LAYER）───────────────────────────────────────────
just key-show                     # 显示 user age 公钥（可分享）
just key-destroy                  # 销毁 user 密钥文件（不可逆）
just key-new-host <alias> [dest]  # 生成 host keypair（仓外交付副本，chmod 400）
just key-show-host <alias> [src]  # 显示 host 交付副本的公钥
just key-add-host <alias> <age1…> [domain=srv]  # 公钥接线进 .sops.yaml（增量）
just key-install-host <alias> [src]  # host identity 合并进本机 key 文件（own host，幂等）
just key-remove <alias>           # 撤销密钥（接受短名 lab 或全名 host_lab）
just key-rotate-user <age1…>      # user key 轮换（三步引导）
just key-rotate-host <age1…>      # host key 轮换（四步：先加后撤，无裸窗口）

# ── rules：策略（RULE LAYER，.sops.yaml = 策略真值 + 分发层）──────────────
just rules-init                   # 仅缺失时重建；对已演化文件拒绝（防打回单 key）
just rules-reset                  # 硬重置到基线（host keys + 轮换全部丢失，慎用）
just rules-destroy                # 删除 .sops.yaml

# ── 明文模板实例（PLAIN LAYER，secrets/plan/**，不入仓）─────────────────
just secrets-plan-create          # 生成所有明文模板实例（填写前对照）
just secrets-plan-destroy         # 删除所有明文模板实例

# ── 一致性与审计 ─────────────────────────────────────────────────────
just secrets-sync                 # sops updatekeys ×全部（规则↔密文对齐）
just secrets-verify               # 收件人一致性审计（NO-RULE / DRIFT；CI 同款）
just secrets-status               # 三层审计（key / rule / blob + 本机 identity）
just secrets-destroy-all          # 销毁全部 sops 相关内容（不可逆）
```

### cachix — the public binary-cache axis (redskaber-nix-config)

```bash
# 缓存可达性探测（公共信息，无需 token）+ 本机 substituter 接线 + 推送半场状态
just cachix-status               # 一屏：URL 探测 / 受信公钥 / CI 与本地推送半场

# token 注册流（准备段：注册进 secrets 体系 + 交互录入，一条命令闭合）
just cachix-token                # 注册 cachix-token 秘密（三层）+ secret-set 录入值
                                  #   token 来自 https://app.cachix.org/cache/
                                  #   redskaber-nix-config → Auth Tokens（owner-only）

# 本地推送（token 解析顺序：CACHIX_AUTH_TOKEN env → cachix-token 秘密）
just cachix-push /nix/store/…    # 推送指定 store 路径（cachix 二进制：$CACHIX_BIN >
                                  #   PATH > nix shell nixpkgs#cachix）
```

### commit — commit-convention deployment

```bash
# 为 nix-config 仓库部署规则文件与钩子
just commit-setup

# 为任意 Git 仓库安装 husky 钩子（不复制配置文件；缺省当前目录）
just commit-husky-install [path=.]

# 单独复制 commitlint 和 commitizen 配置文件到项目（缺省当前目录）
just commit-project-rules [path=.]

# 部署全局兼容规则（可选）
just commit-global-rules
```

### Maintenance

```bash
just dump                        # 导出项目文件树 + 拼接全文到 tmp/（文档/审计用）
```

---
