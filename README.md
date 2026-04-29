# nix-config

> 声明式、可复现、多平台的系统与开发环境管理。  
> 作者: [@Redskaber](https://github.com/Redskaber) · 构建于 Nix Flakes + Home Manager + SOPS-Nix

---

## 架构总览

系统采用严格的层级化管道架构，每层职责单一、边界明确，依赖方向自上而下单向流动。

```
┌────────────────────────────────────────────────────────┐
│  ENTRY LAYER  ·  flake.nix                             │
│  统一入口 · 输入声明 · 输出路由 · 多平台分发           │
└──────────────┬─────────────────────┬───────────────────┘
               │                     │
  ┌────────────▼──────────┐ ┌────────▼──────────────────┐
  │  SYSTEM LAYER         │ │  USER LAYER               │
  │  nixos/               │ │  home/                    │
  │  硬件·驱动·安全·服务  │ │  应用·开发环境·窗口管理器 │
  └────────────┬──────────┘ └────────┬──────────────────┘
               │                     │
  ┌────────────▼─────────────────────▼───────────────────┐
  │  SHARED LAYER  ·  lib/shared/                        │
  │  Schema 定义 · 枚举类型 · 结构验证 · 跨层共享状      │
  └──────────────────────────────────────────────────────┘
               │
  ┌────────────▼──────────────────────────────────────────┐
  │  SECRET LAYER  ·  secrets/ + .sops.yaml               │
  │  Age 加密 · SOPS 管理 · 最小权限 · 运行时注入         │
  └───────────────────────────────────────────────────────┘
```

### 设计原则

| 原则     | 体现                                                                        |
| -------- | --------------------------------------------------------------------------- |
| 依赖倒置 | `lib/shared` 定义抽象 schema，上层模块依赖抽象而非具体实现                  |
| 管道式   | `flake.nix → shared → nixos/home → modules` 单向数据流                      |
| 层级化   | entry / system / user / shared / secret 五层，职责不交叉                    |
| 增量模式 | 每个子目录均为独立模块，可单独启用/禁用，不影响其他模块                     |
| 策略管理 | `shared.nix` 集中声明平台、驱动、WM、Shell 等策略选项                       |
| 状态机   | `lib/shared/schema.nix` 通过 enum 约束合法状态集合                          |
| 生命周期 | devShell 的 `preInputsHook / postInputsHook / preShellHook / postShellHook` |
| 边界明确 | system layer 不感知用户配置，user layer 不直接操作硬件                      |
| 生成不变 | `shared.nix` 由模板生成（覆盖写入），不可 sed 原地 patch                    |

---

## 目录结构

```
nix-config/
├── flake.nix               # entry layer: input declarations, output routing
├── shared.nix              # generated policy layer: produced by just shared-generate; do not edit username manually
│
├── lib/
│   └── shared/
│       ├── default.nix     # shared 加载器：两阶段初始化（fix-pkgs + reload）
│       └── schema.nix      # 类型系统：enum 枚举、struct 验证、常量定义
│
├── nixos/                  # 系统层（NixOS only）
│   └── core/
│       ├── base/           # 基础：boot · network · user · i18n · sound · bluetooth
│       ├── drive/          # 驱动：AMD · Intel · NVIDIA · nvidia-prime
│       ├── exp/            # 实验：虚拟化 · 容器
│       ├── sec/            # 安全：PAM · polkit · SOPS secret 注入
│       └── srv/            # 服务：DB(pg/mysql/mongo/redis) · desktop · hardware · log
│
├── home/                   # 用户层（Home Manager）
│   ├── core/
│   │   ├── app/            # 应用：nvim · wezterm · kitty · tmux · vscode · zed · mpv …
│   │   ├── dev/            # 开发环境：c · cpp · go · java · js · lua · nix · python · rust · zig …
│   │   ├── srv/            # 用户服务：mako · playerctld
│   │   └── sys/            # 系统工具：zsh · git · starship · direnv · fzf · fonts …
│   ├── wm/
│   │   ├── hyprland/       # Wayland WM（主力）
│   │   ├── niri/           # Wayland WM（备选）
│   │   └── gnome/          # GNOME
│   └── hosts/
│       ├── nixos/          # NixOS 主机入口
│       ├── linux/          # 通用 Linux（standalone HM）
│       ├── macos/          # macOS
│       └── wsl/            # WSL2
│
├── secrets/
│   ├── chipr/              # 加密文件（SOPS + Age，提交到 Git）
│   └── plan/               # 明文模板（仅本地，不提交）
│
├── export/
│   ├── nixos/              # 可复用 NixOS 模块（供外部 flake 引用）
│   └── home/               # 可复用 Home Manager 模块
│
├── overlays/               # nixpkgs overlay：additions · modifications · unstable
├── pkgs/                   # 自定义 derivation
│
├── scripts/
│   └── just/               # justfile 子模块（按职责单一职责分层）
│       ├── shared.just     # shared.nix 生成（tmpl → generate → overwrite）
│       ├── hardware.just   # NixOS 硬件配置生成
│       ├── flake.just      # flake inputs 依赖管理
│       ├── devenv.just     # 开发环境 profile 管理（pdshell）
│       └── sops.just       # Age 密钥 + SOPS 加密生命周期（plan/chipr 分层）
│
├── docs/
│   └── tmpl/
│       ├── shared.nix.tmpl # policy layer template (__USERNAME__ placeholder)
│       └── sops/           # SOPS secret YAML templates
│
└── justfile                # 任务自动化入口（全局变量 + import 子模块）
```

---

## 核心机制

### 1. 共享层 — 两阶段初始化

`lib/shared` 解决了 Nix 中"配置依赖 pkgs，pkgs 依赖配置"的循环问题：

```
阶段一: schema (枚举/结构定义) + joker_pkgs (临时 pkgs)
↓
阶段二: 用户 shared.nix 读取 schema，填充真实配置
↓
fullShared = schema ∪ core_pkgs ∪ user_shared
```

`schema.nix` 通过 `nix-types` 的 `enum` 构造器约束合法值，任何非法的 platform / arch / drive 在求值阶段即报错，而非运行时失败。

### 2. 策略层 — shared.nix 生成机制

`shared.nix` 是整个系统的单一真相源，所有平台相关决策集中于此。

**关键设计：生成不变（Generate, Don't Mutate）**

```
docs/tmpl/shared.nix.tmpl   手动维护，含 __USERNAME__ 占位符
    ↓  just shared-generate
shared.nix             生成产物，覆盖写入，不可 sed patch
    ↓
flake.nix / nixos / home   通过 specialArgs 消费
```

`sed` 原地 patch 是运行时 mutation，破坏了"文件内容完全由声明决定"的不变式。  
正确做法是 **模板 → 生成 → 覆盖**，`shared.nix` 的用户名字段只有一个合法写入路径：`just shared-generate`。

切换平台只需修改 `shared.nix.tmpl`，下游所有模块通过 `specialArgs` / `extraSpecialArgs` 接收 `shared`，不直接依赖具体值。

### 3. 开发环境管道 — pdshell

开发环境由外部 flake [`pdshell`](https://github.com/Redskaber/pdshell) 驱动，实现管道式 shell 构建：

```
组合定义 (combinFrom)
    → 策略解析 (per-lang config)
    → 输入合并 (buildInputs ∪ nativeBuildInputs)
    → 钩子组合 (preInputsHook · postInputsHook · preShellHook · postShellHook)
    → 验证
    → mkShell 输出
```

生命周期钩子：

| 钩子             | 时机                                |
| ---------------- | ----------------------------------- |
| `preInputsHook`  | 依赖注入前                          |
| `postInputsHook` | 依赖注入后、shell 启动前            |
| `preShellHook`   | 进入 shell 时（最先）               |
| `postShellHook`  | 进入 shell 时（最后，用于欢迎信息） |

复合环境示例：

```nix
# home/core/dev/python/machine.nix
{
  combinFrom = [ dev.c dev.python ];   # 合并 C + Python 的所有输入
  postInputsHook = ''
    export PYTHONPYCACHEPREFIX="$PWD/.cache/python"
    export UV_CACHE_DIR="$PWD/.cache/uv"
  '';
}
```

### 4. 安全层 — SOPS + Age（分层管理）

```
TMPL LAYER    docs/tmpl/sops/**  static YAML templates (__USERNAME__ placeholder)
    ↓  sed(username/pubkey) → overwrite
KEY LAYER     age-keygen → ~/.config/sops/age/keys.txt
    ↓
RULE LAYER    .sops.yaml (tmpl → sed → overwrite，非原地 patch)
    ↓
PLAIN LAYER   secrets/plan/**   明文实例（不提交 Git，bootstrap 参考）
              BOOTSTRAP: shared.nix.username → sops-plan-create-all
    ↓
CIPHER LAYER  secrets/chipr/**  SOPS 加密（提交 Git，运行时解密）
              BOOTSTRAP:      shared.nix.username → sops-chipr-create-*（首次写入）
              POST-BOOTSTRAP: shared.nix.secrets.* → sops-chipr-create-*（重写）
              POST-BOOTSTRAP: shared.nix.secrets.* → sops-chipr-read-*（读取）
    ↓
RUNTIME       initrd 阶段 sops-nix 解密 → /run/secrets/
    ↓
SERVICE       mode=0440 · owner=root · group=<service>
```

**分层设计原则：**

- `plan`（明文）与 `chipr`（密文）命令集完全分离 —— 不同生命周期、不同受众、不同安全级别
- `sops-init` 只负责基础设施（目录结构、密钥、规则），不自动执行任何交互式加密
- 加密写入（`sops-chipr-create-*`）均为独立命令，需要显式执行
- 销毁操作细粒度分级（key / rules / plan / chipr / all），防止误操作

**统一信息源：**

所有阶段均从 `shared.nix` 读取用户名，`NIXOS_USERNAME` 环境变量不再需要。`just init <username>` 会先通过 `just shared-generate` 生成 `shared.nix`，后续所有 sops 操作均从该文件读取，流程完全自洽。

| 阶段           | 信息源            | 前置条件                      | 命令集                                                  |
| -------------- | ----------------- | ----------------------------- | ------------------------------------------------------- |
| BOOTSTRAP      | `shared.nix` 文件 | `just shared-generate` 已执行 | `sops-init`, `sops-rules-regen`, `sops-plan-create-all` |
| POST-BOOTSTRAP | `shared.nix` 文件 | `just shared-generate` 已执行 | `sops-chipr-create-*`, `sops-chipr-read-*`              |

POST-BOOTSTRAP 操作从 `shared.nix` 的 `secrets.*` 字段直接读取 secret 文件路径，路径已由 shared.nix 唯一确定，无需任何外部环境变量。

---

## justfile 命令参考

### 全局

```bash
# 完整初始化（新机器），<username> 是唯一需要提供的参数
just init yourname              # shared-generate → hardware-generate → sops-init
just sops-init                  # init sops infra only (requires just shared-generate first)
just sops-plan-create-all       # generate plaintext templates (requires just shared-generate first)
just sops-rules-regen           # rebuild .sops.yaml rules (requires just shared-generate first)

# POST-BOOTSTRAP 阶段（shared.nix 已存在，路径从文件读取）
just sops-chipr-create-userpwd             # 无需 NIXOS_USERNAME
just sops-chipr-read-mongodb               # 无需 NIXOS_USERNAME
```

### shared — 策略层生成

```bash
just shared-generate <username>  # generate shared.nix from template (overwrite)
just shared-show-username         # print username from shared.nix (diagnostic)
just shared-validate              # verify template has __USERNAME__ placeholders
```

### hardware — 硬件配置

```bash
just hardware-generate     # 生成 nixos/core/base/hardware.nix（首次或硬件变更后）
just hardware-show         # 显示当前 hardware.nix 内容
```

### flake — 依赖管理

```bash
just flake-update-all      # 更新所有 inputs
just flake-update <pkg>    # 更新单个 input
just flake-update-not-sops # update all inputs except sops-nix
just flake-update-configs  # update only *-config inputs
just flake-update-dry      # dry-run: show what would change (no file writes)
just flake-show            # show all flake outputs
just flake-lock-show       # show current locked versions (read-only)
```

### devenv — 开发环境

```bash
just devenv-create rust                    # 创建单语言 profile
just devenv-create-from python machine     # 创建复合变体 profile
just devenv-use rust                       # 进入已有单语言环境
just devenv-use-from python machine        # 进入已有复合变体环境
just devenv-update rust                    # 强制重建单语言环境
just devenv-create-all                     # 创建所有已知环境
just devenv-delete-all                     # 删除所有 profile
just devenv-show                           # 列出所有可用 devShell
just devenv-list                           # 树状显示已创建 profile
```

### sops — 密钥与加密

```bash
# ── BOOTSTRAP（需要先执行 just shared-generate <username>）──────────────────
# 初始化
just sops-init             # 目录 + 密钥 + 规则（从 shared.nix 读取用户名）
just sops-init-with-plan   # 同上 + 生成所有明文模板

# RULE 层（bootstrap 操作）
just sops-rules-regen      # 重新生成 .sops.yaml（密钥轮转后）

# PLAIN 层（bootstrap 操作）
just sops-plan-create-all  # 生成所有明文模板实例

# ── POST-BOOTSTRAP（从 shared.nix 读取路径，无需 NIXOS_USERNAME）───────────
# CIPHER 层 — 加密写入（交互式，路径由 shared.nix 提供）
just sops-chipr-create-userpwd             # 加密用户系统密码
just sops-chipr-create-nix                 # 加密 GitHub token
just sops-chipr-create-mongodb             # 加密 MongoDB 密码
just sops-chipr-create-mysql               # 加密 MySQL root + 用户密码
just sops-chipr-create-postgresql          # 加密 PostgreSQL 密码
just sops-chipr-create-redis               # 加密 Redis 密码
just sops-chipr-create-all                 # 交互式加密所有 secret

# CIPHER 层 — 解密读取（路径由 shared.nix 提供）
just sops-chipr-read-userpwd               # 解密显示用户密码
just sops-chipr-read-nix                   # 解密显示 GitHub token
just sops-chipr-read-mongodb               # 解密显示 MongoDB 密码
just sops-chipr-read-mysql                 # 解密显示 MySQL 密码
just sops-chipr-read-postgresql            # 解密显示 PostgreSQL 密码
just sops-chipr-read-redis                 # 解密显示 Redis 密码

# ── 无阶段限制（固定路径，无需 USERNAME）────────────────────────────────────
just sops-key-show                         # 显示 age 公钥
just sops-key-destroy                      # 销毁密钥（不可逆）
just sops-rules-destroy                    # 删除 .sops.yaml
just sops-plan-destroy                     # 删除所有明文模板
just sops-chipr-destroy                    # 删除所有加密文件（不可逆）
just sops-destroy-all                      # 销毁全部 sops 相关内容（不可逆）
```

---

## 快速开始

### 前置条件

- Nix 2.22+（启用 `nix-command`、`flakes`、`pipe-operators` experimental features）
- 目标平台: NixOS · Linux · macOS · WSL2

### 初始化（新机器）

> 注意：nixos 在首次 build 之后，非存在 `/` 下的子目录会被清空，如果需要保存配置，请在 `/` 下的子目录。

```bash
git clone https://github.com/Redskaber/nix-config ~/.config/nix-config
cd ~/.config/nix-config

# 完整初始化（<username> 是唯一需要提供的参数）：
#   1. 从 shared.nix.tmpl 生成 shared.nix（覆盖写入，非 sed patch）
#   2. 生成 hardware.nix
#   3. 初始化 sops 目录 + 密钥 + 规则文件（从 shared.nix 读取用户名）
just init yourname

# 可选：生成明文模板参考（从 shared.nix 读取，无需额外参数）
just sops-plan-create-all

# 加密写入各 secret（交互式，按需执行）
# 注: chipr-create-* 从 shared.nix 读取路径，无需 NIXOS_USERNAME
just sops-chipr-create-userpwd
just sops-chipr-create-nix
# … 其余 sops-chipr-create-* 命令
```

### 部署

```bash
# NixOS 系统 + Home Manager
sudo nixos-rebuild switch --flake .#kilig-nixos

# Home Manager（NixOS 内）
home-manager switch --flake .#kilig@nixos

# 独立 Home Manager（非 NixOS Linux）
home-manager switch --flake .#kilig@linux
```

### 开发环境

```bash
# 进入单语言环境
nix develop .#rust
nix develop .#python
# or
just devenv-use rust
just devenv-use python

# 进入复合环境
nix develop .#python-machine
# or
just devenv-use-from python machine

# 持久化 profile（离线可用）
just devenv-create rust
just devenv-create-from python machine

# 查看所有可用 devShell
just devenv-show
```

---

## 跨平台支持

| 平台         | 系统层 | 用户层 | 开发环境               |
| ------------ | ------ | ------ | ---------------------- |
| NixOS x86_64 | 完整   | 完整   | 全部                   |
| Linux x86_64 | —      | 完整   | 全部                   |
| macOS ARM64  | —      | 部分   | CLI 为主               |
| WSL2         | —      | 部分   | 全部（需启用 systemd） |

---

## 扩展指南

### 添加应用

```bash
# GUI 应用
home/core/app/<name>.nix

# CLI 工具
home/core/sys/<name>.nix

# 在对应 default.nix 的 imports 中添加引用
```

### 添加开发语言环境

```bash
mkdir home/core/dev/<lang>
# 参考 home/core/dev/python/ 的结构实现 default.nix
# pdshell 会自动发现并注册到 devShells
```

### 添加系统服务

```bash
# 在 nixos/core/srv/ 下创建子目录
# 敏感配置通过 sops.secrets 注入，不硬编码
```

### 修改平台策略

编辑 `docs/tmpl/shared.nix.tmpl`，修改 `platform` / `drive` / `window-manager` 等字段，然后运行 `just shared-generate <username>` 重新生成 `shared.nix`。

### 修改用户名

```bash
just shared-generate newname   # regenerate shared.nix from template with new username
```

---

## 依赖图

```
flake.nix
├── nixpkgs (25.11 / unstable)
├── home-manager (release-25.11)
├── sops-nix
├── nix-types          ← enum 类型系统
├── pdshell            ← 开发环境管道引擎
├── hyprland / hyprland-plugins
├── nixgl              ← 非 NixOS GL 修复
├── nur                ← 社区包
├── zen-browser
├── wechat
└── *-config (flake=false)   ← nvim · starship · wezterm · kitty · tmux
                                vscode · mpv · btop · cava · hypr · rofi
                                swaync · wallust · waybar · wlogout
                                quickshell · niri · emacs
```

`flake=false` 的配置仓库以源码形式引入，由对应模块在 Home Manager 激活时写入目标路径，实现配置与系统声明的统一管理。

---

## 路线图

- [ ] flake inputs 依赖管理器（自动更新策略）
- [ ] 惰性模块加载（提升大型配置的求值速度）
- [ ] NixOS 测试套件（关键路径自动化验证）
- [ ] 模块文档自动生成

---

> 每个目录是一个模块，每个模块是一个函数，每次重建是一次纯函数推导。  
> 系统状态完全由 Git 中的声明决定，机器是声明的投影。
