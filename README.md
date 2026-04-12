# nix-config

> 声明式、可复现、多平台的系统与开发环境管理。  
> 作者: [@Redskaber](https://github.com/Redskaber) · 构建于 Nix Flakes + Home Manager + SOPS-Nix

---

## 架构总览

系统采用严格的层级化管道架构，每层职责单一、边界明确，依赖方向自上而下单向流动。

```
┌──────────────────────────────────────────────────────────────┐
│  ENTRY LAYER  ·  flake.nix                                   │
│  统一入口 · 输入声明 · 输出路由 · 多平台分发                      │
└────────────────────┬─────────────────────┬───────────────────┘
                     │                     │
        ┌────────────▼──────────┐ ┌────────▼──────────────────┐
        │  SYSTEM LAYER         │ │  USER LAYER               │
        │  nixos/               │ │  home/                    │
        │  硬件·驱动·安全·服务    │ │  应用·开发环境·窗口管理器    │
        └────────────┬──────────┘ └────────┬──────────────────┘
                     │                     │
        ┌────────────▼─────────────────────▼───────────────────┐
        │  SHARED LAYER  ·  lib/shared/                        │
        │  Schema 定义 · 枚举类型 · 结构验证 · 跨层共享状态         │
        └──────────────────────────────────────────────────────┘
                     │
        ┌────────────▼──────────────────────────────────────────┐
        │  SECRET LAYER  ·  secrets/ + .sops.yaml               │
        │  Age 加密 · SOPS 管理 · 最小权限 · 运行时注入            │
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

---

## 目录结构

```
nix-config/
├── flake.nix               # 入口层：输入声明、输出路由
├── shared.nix              # 策略层：当前主机的全局配置（单一真相源）
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
└── justfile                # 任务自动化：init · devenv · sops
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

### 2. 策略层 — shared.nix

`shared.nix` 是整个系统的单一真相源，所有平台相关决策集中于此：

```nix
{
  arch            = shared.arch.x86_64-linux;
  platform        = shared.platform.nixos;
  drive           = shared.drive-group.intel;
  window-manager  = shared.window-manager.hyprland;
  display-manager = shared.display-manager.ly;
  editor          = shared.editor.nvim;
}
```

切换平台只需修改这一个文件，下游所有模块通过 `specialArgs` / `extraSpecialArgs` 接收 `shared`，不直接依赖具体值。

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

### 4. 安全层 — SOPS + Age

```
密钥生成  age-keygen → ~/.config/sops/age/keys.txt
    ↓
加密规则  .sops.yaml (path_regex → key_groups)
    ↓
加密写入  secrets/chipr/**/*.yaml  (提交 Git)
    ↓
运行时    initrd 阶段 sops-nix 解密 → /run/secrets/
    ↓
服务访问  mode=0440 · owner=root · group=<service>
```

secrets 目录分为两层：

- `secrets/plan/` — 明文模板，说明每个 secret 的结构，不提交
- `secrets/chipr/` — SOPS 加密后的实际文件，提交到 Git

---

## 快速开始

### 前置条件

- Nix 2.22+ (启用 `nix-command` 和 `flakes` experimental features, `pipe-operators`)
- 目标平台: NixOS · Linux · macOS · WSL2

### 初始化（新机器）

> 注意：nixos 在首次build 之后，非存在 `/` 下的子目录 会被清空，如果需要保存配置，请在 `/` 下的子目录。

```bash
git clone https://github.com/Redskaber/nix-config ~/.config/nix-config
cd ~/.config/nix-config

# 设置用户名（单一真相源）
export NIXOS_USERNAME=yourname

# 完整初始化：shared.nix 替换用户名 + 生成 hardware.nix + sops 密钥与加密文件
just init
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
nix develop .#go
# or
just devenv-use rust
just devenv-use python
just devenv-use go

# 进入复合环境
nix develop .#python-machine    # Python + ML 依赖
nix develop .#nix-derivation-free
# or
just devenv-use-from python machine
just devenv-use-from nix derivation-free

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

编辑 `shared.nix`，修改 `platform` / `drive` / `window-manager` 等字段即可，无需改动任何模块内部。

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
