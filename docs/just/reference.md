# just 命令全参考 — 82 recipe × 13 组

> 本文是 README「justfile 命令参考」节的完整版（T13.1 分层重构时从 README 原样迁出）。
> `just --list` 在终端给出同源入口；日常速查（deploy / devenv / secrets 三高频组）见
> [README](../../README.md#日常操作速查)。

> 全量动词面共 82 个 recipe，`[group]` 注解分 13 组（bootstrap / commit / deploy /
> devenv / disk / flake / hardware / keys / maintenance / rules / secrets / services /
> shared）——`just --list` 给出按组组织的全部入口；裸 `just`（无参数）打印
> start-here 地图；secrets 侧的生命周期地图从 `just secrets-guide` 进入。

### 全局（引导入口）

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

### deploy — 主机与部署目标（T2.4，数据驱动）

> 主机清单由 hosts/ 目录枚举，flake 自动发现 —— 加机器 = `mkdir hosts/<name>`
>
> - 两个文件，零 flake 改动；这里的 recipe 同样零硬编码。

```bash
just hosts-list                 # 列出全部可求值主机（nixosConfigurations 键）
just home-targets               # 列出全部独立 home-manager 目标（<user>@<host>）

just nixos-switch <host>        # NixOS 切换（= sudo nixos-rebuild switch --flake .#<host>）
just nixos-test <host>          # test 模式（不写 boot 条目，重启即弃）
just nixos-boot <host>          # boot 模式（T10.2：只设下一代引导，不激活——重启才生效）
just home-switch <host>         # HM 切换（读 shared.nix 用户名 → <user>@<host>）
# 例: just nixos-switch nixos / just home-switch wsl
```

### shared — 策略层生成

```bash
just shared-generate <username>  # 从模板生成 shared.nix（唯一合法写入方式）
just shared-show-username        # 显示当前 shared.nix 中的用户名（诊断）
just shared-validate             # 验证模板占位符存在
just shared-roundtrip            # 验证 shared.nix ⇄ 模板可双向字节一致再生（门禁同源）
```

### hardware — 硬件配置

```bash
just hardware-facter           # 生成 hosts/<hostname>/facter.json（声明式路线，T5.12；首次或硬件变更后）
just hardware-generate         # 生成 hosts/<hostname>/hardware.nix（legacy 路线，nixos-generate-config）
just hardware-show             # 显示当前 hardware.nix 内容
just hardware-list             # 列出所有已配置主机
```

### disk — 磁盘布局应用 + 状态策略检视（T5.13 + T5.14）

```bash
just disk-show <host>          # 只读：求值该主机 disko 布局的推导结果（fileSystems/boot 接线）
just persist-show <host>       # 只读：该主机的状态契约（生存清单 + ephemeral-root 回滚配方）
just disk-format <host>        # 破坏性：从锁定闭包构建并运行 pinned 分区/格式化/挂载脚本
                               # （重装/installer 场景；extra args 透传，如 --dry-run）
```

### services — 按需服务管理

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

### flake — 依赖管理

```bash
just flake-update-all            # 更新所有 inputs
just flake-update <pkg>          # 更新单个 input
just flake-update-not-sops       # 更新除 sops-nix 外的所有 inputs（sops-nix 版本锁定）
just flake-update-configs        # 仅更新 *-config inputs（外部配置仓库）
just flake-update-dry            # dry-run：预览会变更哪些 inputs（不修改 flake.lock）
just flake-show                  # 显示所有 flake 输出（含 devShells）
just flake-lock-show             # 显示当前锁定版本（只读）
```

### devenv — 开发环境

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

**profile 命名规则：** `<username>-<lang>[-<class>]`，存储于 `~/.local/state/nix/profiles/dev/<lang>/`。

### secrets — 密钥与加密（三对象 × 生命周期动词，注册表驱动）

> 入口是 `just secrets-guide`（状态机 + 动词矩阵 + 情景流）；
> `just secrets-list` 随时回答"有哪些秘密、缺哪个"。
> 模板 `docs/tmpl/sops/sops-rules.yaml.tmpl` 携带双渲染模式：
> user key 行无条件渲染，host key 行（`# __HOST__` 标记）由引导调用决定。
> 仓库携带的是**维护者的**密文（对你不可解）——fork 接管流程见 [docs/architecture/mechanisms.md §5 安全层](../architecture/mechanisms.md#5-安全层--sops--age分层管理)。

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

### commit — 提交规范部署

```bash
# 为 nix-config 仓库部署规则文件与钩子
just commit-setup

# 为任意 Git 仓库安装 husky 钩子（不复制配置文件）
just commit-husky-install <path>

# 单独复制 commitlint 和 commitizen 配置文件到项目
just commit-project-rules <path>

# 部署全局兼容规则（可选）
just commit-global-rules
```

### 维护（maintenance）

```bash
just dump                        # 导出项目文件树 + 拼接全文到 tmp/（文档/审计用）
```

---
