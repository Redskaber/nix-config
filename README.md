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
  │  Schema 定义 · 枚举类型 · 结构验证 · 跨层共享状态    │
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
| 状态机   | `lib/shared/schema.nix` 通过 enum 约束合法状态集合，求值期即报错            |
| 生命周期 | devShell 的 `preInputsHook / postInputsHook / preShellHook / postShellHook` |
| 边界明确 | system layer 不感知用户配置，user layer 不直接操作硬件                      |
| 生成不变 | `shared.nix` 由模板生成（覆盖写入），不可 sed 原地 patch                    |
| 数据驱动 | sops.just 零硬编码路径，所有 secret 路径运行时从 shared.nix 读取            |

---

## 目录结构

```
nix-config/
├── flake.nix               # entry layer: 输入声明、输出路由、多平台分发
├── shared.nix              # 生成的策略层：由 just shared-generate 生成，禁止手动编辑用户名
│
├── lib/
│   └── shared/
│       ├── default.nix     # 共享加载器：两阶段初始化（schema + runtime）
│       ├── shared/
│       │   ├── enum.nix    # 枚举类型：arch / platform / wm / shell / drive-group 等
│       │   ├── schema.nix  # 结构验证：user / git / rbw / secrets / shared 的类型约束
│       │   ├── fn.nix      # 工具函数
│       │   └── const.nix   # 常量定义
│       ├── runtime/
│       │   └── default.nix # 运行时合成：pkgs / upkgs / isNixOS / orc 注入
│       └── template.nix    # 配置模板参考（不直接导入）
│
├── nixos/                  # 系统层（NixOS only）
│   ├── core/
│   │   ├── base/           # 基础：boot · network · user · i18n · sound · bluetooth · memory · portal
│   │   ├── drive/          # 驱动：AMD · Intel · NVIDIA · nvidia-prime（多驱动组合支持）
│   │   ├── exp/            # 实验：steam · clash-verge · obs · compat · xwayland
│   │   ├── sec/            # 安全：PAM · polkit · SOPS secret 注入（age/sops/ssh-to-age）
│   │   └── srv/            # 服务：
│   │       ├── db/         #   数据库：PostgreSQL · MySQL(MariaDB) · MongoDB · Redis
│   │       ├── desktop/    #   桌面：flatpak · gvfs · tumbler
│   │       ├── hardware/   #   硬件：bluetooth · firmware · power · printing · storage
│   │       ├── log/        #   日志：logrotate（MySQL/PostgreSQL 日志轮转）
│   │       └── security/   #   安全服务：SSH · gnupg keyring
│   ├── dm/                 # 显示管理器：gdm · ly · sddm · lemurs（由 shared.display-manager 选择）
│   └── wm/                 # 窗口管理器：hyprland（含插件）· niri · gnome
│
├── home/                   # 用户层（Home Manager）
│   ├── core/
│   │   ├── base/           # 基础：字体 · i18n(fcitx5) · portal · XDG
│   │   ├── exp/            # 扩展功能（可选模块）
│   │   │   ├── app/        # GUI 应用：
│   │   │   │   ├── browser/    #   浏览器：google-chrome · qutebrowser · w3m · zen-browser
│   │   │   │   ├── dl/         #   下载：baidupcs-go · xunlei · downloader
│   │   │   │   ├── editor/     #   编辑器：nvim · emacs · vscode · zed · kiro
│   │   │   │   ├── fm/         #   文件管理：nemo
│   │   │   │   ├── game/       #   游戏：lutris · minecraft(prismlauncher)
│   │   │   │   ├── im/         #   即时通讯：discord(vesktop) · qq · wechat
│   │   │   │   ├── image/      #   图像：gimp · imagemagick · imv · ghostscript · mermaid-cli · tectonic
│   │   │   │   ├── misc/       #   杂项：showmethekey
│   │   │   │   ├── music/      #   音乐：mpd · easyeffects · spotify · playerctld · cnmplayer
│   │   │   │   ├── note/       #   笔记：obsidian
│   │   │   │   ├── office/     #   办公：pandoc · pdf · wpsoffice · unoconv
│   │   │   │   ├── re/         #   逆向：ghidra · imhex · cutter
│   │   │   │   ├── terminal/   #   终端：wezterm · kitty
│   │   │   │   └── video/      #   视频：obs-studio
│   │   │   └── sys/        # 系统工具：
│   │   │       ├── ai/         #   AI：claude-code · opencode · gemini-cli
│   │   │       ├── base/       #   基础 CLI：git · fzf · bat · eza · fd · ripgrep · zoxide
│   │   │       │               #   atuin · starship · direnv · tmux · rbw · just · jq · yq
│   │   │       │               #   wl-clipboard · cliphist · wl-clip-persist · tealdeer
│   │   │       ├── compat/     #   兼容：appimage-run
│   │   │       ├── fs/         #   文件系统：compress(zip/p7zip/zstd) · duf
│   │   │       ├── media/      #   媒体：ffmpeg · mpv
│   │   │       ├── misc/       #   杂项：cava
│   │   │       ├── monitor/    #   监控：btop · htop · bottom
│   │   │       └── shell/      #   Shell：zsh(fzf-tab+atuin) · fish(fzf-fish+autopair)
│   │   ├── sec/            # 用户安全：rbw(bitwarden CLI)
│   │   └── srv/            # 用户服务：
│   │       ├── db/         #   数据库客户端工具
│   │       ├── notify/     #   通知：mako
│   │       └── security/   #   安全：gnupg keyring
│   ├── wm/
│   │   ├── hyprland/       # Wayland WM（主力）：hyprland + 完整主题栈
│   │   │   └── theme/      # quickshell · rofi · swaync · satty · swayosd · wallust · waybar · wlogout · qtct
│   │   ├── niri/           # Wayland WM（备选）：niri + 主题栈
│   │   │   └── theme/      # satty · swaylock · swaync · swayosd · waybar · wlogout
│   │   └── gnome/          # GNOME（骨架）
│   └── env/
│       ├── base/           # 全局基础包：clang · cmake · rustc · cargo · python312 · nodejs_24
│       │                   # 调试工具：valgrind · strace · ltrace · pciutils · vulkan-tools
│       └── dev/            # pdshell devShell 定义（每语言一目录）
│           ├── c/ cpp/ go/ java/ javascript/ typescript/
│           ├── lisp/ lua/ nix/ python/ re/ rust/ zig/
│           └── default.nix # 复合环境：default(全语言) · cpython(C+C++Python) · godot
│
├── host/                   # 平台入口（Home Manager 激活点）
│   ├── nixos/              # NixOS 主机入口（x86_64-linux）
│   ├── linux/              # 通用 Linux（standalone HM + nixGL）
│   ├── macos/              # macOS（standalone HM + nixGL）
│   └── wsl/                # WSL2（standalone HM + nixGL）
│
├── secrets/
│   ├── chipr/              # SOPS 加密文件（提交到 Git；.sops.yaml 管控解密权限）
│   └── plan/               # 明文模板实例（明文！必须在 .gitignore 中，禁止提交）
│
├── export/
│   ├── nixos/              # 可复用 NixOS 模块（供外部 flake 引用）
│   └── home/               # 可复用 Home Manager 模块
│
├── overlays/               # nixpkgs overlay：additions · modifications · unstable-packages
├── pkgs/                   # 自定义 derivation
│
├── scripts/
│   └── just/               # justfile 子模块（单一职责分层）
│       ├── shared.just     # shared.nix 生成（tmpl → generate → overwrite）
│       ├── hardware.just   # NixOS 硬件配置生成
│       ├── flake.just      # flake inputs 依赖管理
│       ├── devenv.just     # 开发环境 profile 管理（pdshell）
│       └── sops.just       # Age 密钥 + SOPS 加密生命周期（plan/chipr 数据驱动分层）
│
├── docs/
│   └── tmpl/
│       ├── shared.nix.tmpl # 策略层模板（__USERNAME__ 占位符；提交到 Git）
│       └── sops/           # SOPS secret YAML 模板（镜像路径层级结构）
│
└── justfile                # 任务自动化入口（全局变量 + import 子模块）
```

---

## 核心机制

### 1. 共享层 — 两阶段初始化

`lib/shared` 解决了 Nix 中"配置依赖 pkgs，pkgs 依赖配置"的循环问题：

```
阶段一 (shared/):  schema(枚举/结构定义) + enum(合法状态集合)
                   ↓ 提供类型约束，不依赖 pkgs
阶段二 (runtime/): user_shared(shared.nix 用户填充) → runtime_shared
                   ↓ 注入: pkgs · upkgs · isNixOS · orc
fullShared = schema ∪ enum ∪ user_shared ∪ runtime
```

`lib/shared/default.nix` 接受可选参数 `scfpath`（默认 `../../shared.nix`），允许在测试或多机器场景中指向不同的策略文件：

```nix
# 默认用法（flake.nix 中）
shared = import ./lib/shared { inherit self nixpkgs nixpkgs-unstable inputs; };

# 自定义策略文件路径（多机器场景）
shared = import ./lib/shared {
  inherit self nixpkgs nixpkgs-unstable inputs;
  scfpath = ./machines/server.nix;
};
```

`schema.nix` 通过 `nix-types` 的 `enum` 构造器约束合法值，任何非法的 platform / arch / drive 在求值阶段即报错。

`runtime/default.nix` 合成后的 `fullShared` 包含以下运行时字段：

| 字段           | 来源          | 说明                                          |
| -------------- | ------------- | --------------------------------------------- |
| `pkgs`         | runtime 注入  | 稳定版 nixpkgs（含 overlays + config）        |
| `upkgs`        | runtime 注入  | unstable nixpkgs（含 allowUnfree）            |
| `isNixOS`      | runtime 计算  | `platform == nixos`，用于条件模块加载         |
| `orc`          | runtime 注入  | configuration-orchestrator lib（wallust 注入）|
| `_user_shared` | runtime 保留  | 原始 user_shared 快照（调试/内省用）          |

随后 `shared` 作为 `specialArgs`/`extraSpecialArgs` 传递给所有 NixOS/Home Manager 模块。

`flake.nix` 还暴露了 `api.inputs` 输出，供 `flake-update-not-sops` 等 just 命令动态枚举 inputs：

```nix
# flake.nix
api.inputs = inputs;  # 允许: nix eval .#api.inputs --json | jq -r 'keys'
```

### 2. 策略层 — shared.nix 生成机制

`shared.nix` 是整个系统的单一真相源，所有平台相关决策集中于此。

**生成不变（Generate, Don't Mutate）**

```
docs/tmpl/shared.nix.tmpl   手动维护，含 __USERNAME__ 占位符（提交 Git）
    ↓  just shared-generate <username>
shared.nix                  生成产物，覆盖写入，不可 sed patch（提交 Git）
    ↓  flake.nix import lib/shared
fullShared                  运行时合成（pkgs + user_shared + runtime）
    ↓  specialArgs / extraSpecialArgs
nixos/ · home/              通过 { shared, ... } 消费
```

**可配置枚举（lib/shared/shared/enum.nix）：**

| 字段              | 合法值                                                                                                    |
| ----------------- | --------------------------------------------------------------------------------------------------------- |
| `arch`            | `x86_64-linux` · `aarch64-linux` · `x86_64-darwin` · `aarch64-darwin` · `i686-linux`                    |
| `platform`        | `nixos` · `linux` · `macos` · `wsl`                                                                      |
| `window-manager`  | `hyprland` · `niri` · `gnome`（每个值携带 `portal` 策略）                                                |
| `display-manager` | `ly` · `gdm` · `sddm` · `lemurs`                                                                         |
| `drive-group`     | `intel` · `amd` · `nvidia` · `nvidia-prime` · `amd-nvidia` · `amd-nvidia-prime` · `intel-nvidia` · `intel-nvidia-prime` |
| `shell`           | `zsh` · `fish` · `bash`                                                                                   |
| `editor`          | `nvim` · `vim` · `code` · `zeditor`                                                                      |
| `version`         | `v25_11`（值 `"25.11"`，用于 `system.stateVersion`）                                                     |

`window-manager` 枚举值内嵌 `portal` 策略，`nixos/core/base/portal.nix` 直接消费：

```nix
# 枚举值结构示例
hyprland = { portal = { default = [ "hyprland" "gtk" ]; extraPortals = ...; wlr = false; }; };
niri     = { portal = { default = [ "wlr" "gtk" ];      extraPortals = ...; wlr = true;  }; };
gnome    = { portal = { default = [ "gtk" ];             extraPortals = ...; wlr = false; }; };
```

### 3. 开发环境管道 — pdshell

开发环境由外部 flake [`pdshell`](https://github.com/Redskaber/pdshell) 驱动，实现管道式 shell 构建：

```
组合定义 (combinFrom)
    → 策略解析 (per-lang config: buildInputs · nativeBuildInputs · hooks)
    → 输入合并 (buildInputs ∪ nativeBuildInputs)
    → 钩子组合 (preInputsHook · postInputsHook · preShellHook · postShellHook)
    → 验证
    → mkShell 输出 → devShells.${system}
```

**生命周期钩子：**

| 钩子             | 时机                     | 典型用途                          |
| ---------------- | ------------------------ | --------------------------------- |
| `preInputsHook`  | 依赖注入前               | 环境检查、前置条件验证            |
| `postInputsHook` | 依赖注入后、shell 启动前 | 导出环境变量（CC/CXX/GOPROXY 等） |
| `preShellHook`   | 进入 shell 时（最先）    | 进入动画、欢迎前置                |
| `postShellHook`  | 进入 shell 时（最后）    | 欢迎信息、操作提示、alias 注册    |

**复合环境（combinFrom）：**

```nix
# home/core/dev/python/machine.nix — ML/DL 环境组合 C + Python
default = {
  shell = "zsh";
  combinFrom = [ dev.c dev.python ];   # 合并两个环境的所有 inputs 和 hooks
  postInputsHook = ''
    export LD_LIBRARY_PATH="${pkgs.gcc.cc.lib}/lib:$LD_LIBRARY_PATH"
    export UV_CACHE_DIR="$PWD/.cache/uv"
  '';
};
```

**可用 devShells 速查：**

| Shell 名称                     | 组合内容                              | 特性                          |
| ------------------------------ | ------------------------------------- | ----------------------------- |
| `rust`                         | rustc + cargo + rust-analyzer         | clippy · rustfmt              |
| `go`                           | go + gopls + delve                    | 中国镜像 · 项目级缓存         |
| `python`                       | python312 + uv + pyright              | ruff · bytecode 缓存隔离      |
| `python-machine`               | C + Python + gcc.cc.lib               | ML/DL 工具链 · GPU 指引       |
| `python-renpy`                 | python312 + renpy + unrpyc            | Visual Novel 开发             |
| `cpp`                          | pure LLVM (libc++ + clangd)           | lld · lldb · bear · ccache    |
| `c`                            | clang + clangd + lld                  | bear · ccache · cmake · ninja |
| `java`                         | temurin-21 + maven + jdt-ls           | gradle                        |
| `typescript`                   | node24 + tsc + tsx                    | typescript-language-server    |
| `javascript`                   | node24 + biome                        | pnpm · yarn                   |
| `nix`                          | nix + nil + statix + nixfmt           | deadnix · nvd                 |
| `nix-derivation-free`          | + nix-output-monitor + nixpkgs-review | PR 审查工作流                 |
| `nix-derivation-unfree`        | + patchelf + sbomnix + gpg            | 闭源软件构建 · 合规           |
| `nix-derivation-free-security` | + vulnix                              | 安全扫描                      |
| `re`                           | LLVM + 完整逆向工具链                 | pwntools · frida · ghidra     |
| `lua`                          | lua54 + luajit + lua-language-server  | stylua · luarocks             |
| `lisp`                         | sbcl + rlwrap                         | pkg-config · gcc              |
| `zig`                          | zig + zls                             |                               |
| `default`                      | 全语言 combinFrom 合并                | 综合开发环境                  |
| `cpython`                      | C + C++ + Python 组合                 |                               |
| `godot`                        | C + C++ + Python + godot              | 游戏开发                      |

### 4. 安全层 — SOPS + Age（分层管理）

```
TMPL LAYER    docs/tmpl/sops/**  静态 YAML 模板（__USERNAME__ 占位符）
              路径规则: TMPL_PATH / (REL | reverse_username) + .yaml
    ↓
KEY LAYER     age-keygen → ~/.config/sops/age/keys.txt
    ↓
RULE LAYER    .sops.yaml（tmpl → sed → overwrite，非原地 patch）
    ↓
PLAIN LAYER   secrets/plan/**   明文实例（禁止提交 Git，bootstrap 参考）
    ↓
CIPHER LAYER  secrets/chipr/**  SOPS 加密（提交 Git，运行时解密）
    ↓
RUNTIME       initrd 阶段 sops-nix 解密 → /run/secrets/ 或 /run/secrets-for-users/
    ↓
SERVICE       mode=0400/0440 · owner=root/service-user · group=<service-group>
```

**Secret 权限矩阵：**

| Secret                         | mode   | owner    | group       | path prefix              |
| ------------------------------ | ------ | -------- | ----------- | ------------------------ |
| `user.password`                | `0400` | root     | root        | `/run/secrets-for-users` |
| `nix.user.github.access-token` | `0400` | \<user\> | \<user\>    | `/run/secrets`           |
| `mongodb.user.password`        | `0400` | mongodb  | mongodb     | `/run/secrets`           |
| `mysql.root.password`          | `0400` | root     | root        | `/run/secrets`           |
| `mysql.user.password`          | `0440` | root     | mysql       | `/run/secrets`           |
| `postgresql.user.password`     | `0440` | root     | postgres    | `/run/secrets`           |
| `redis.user.password`          | `0440` | root     | redis-\<u\> | `/run/secrets`           |

**数据驱动设计（零硬编码路径）：**

`sops.just` 中所有 secret 路径在运行时从 `shared.nix` 读取：

- `_sops-mkdir` — 遍历所有 `nixos.*` secret 值，`dirname(REL)` → `mkdir -p`
- `_sops-plan-gen` — 只需 dotted key，路径/模板均自动推导
- `_sops-chipr-write` — 单一通用加密写入器，awk ENVIRON 安全替换（防止密码中 `|` `\` 等字符破坏 sed），原子写入（mktemp + mv）

**单一模板推导规则：**

```
REL      = shared.nix 中 dotted key 对应的路径值
TMPL_REL = REL | sed "s|/${U}/|/__USERNAME__/|g; s|redis-${U}|redis-__USERNAME__|g"
TMPL     = SECRETS_TMPL_PATH / TMPL_REL + ".yaml"
```

**`.gitignore` 要求：**

```gitignore
# plaintext secret instances — NEVER commit
secrets/plan/
```

**统一信息源：** 所有阶段均从 `shared.nix` 读取用户名.

| 阶段           | 信息源       | 前置条件                      | 命令集                                                  |
| -------------- | ------------ | ----------------------------- | ------------------------------------------------------- |
| BOOTSTRAP      | `shared.nix` | `just shared-generate` 已执行 | `sops-init`, `sops-rules-regen`, `sops-plan-create-all` |
| POST-BOOTSTRAP | `shared.nix` | `just shared-generate` 已执行 | `sops-chipr-create-*`, `sops-chipr-read-*`              |

### 7. 用户环境层 — home/env

`home/env` 是独立于 `home/core` 的全局运行时环境层，在所有平台的 `host/*/` 入口中与 `home/core` 并列导入：

```
host/<platform>/default.nix
    imports = [ ../../home/core  ../../home/env  ../../home/wm ]
```

**子层职责：**

| 子层         | 路径              | 说明                                                                 |
| ------------ | ----------------- | -------------------------------------------------------------------- |
| `env/base`   | `home/env/base/`  | 全局基础包：编译器(clang/rustc/cargo)、运行时(python312/nodejs_24)、调试工具(valgrind/strace/ltrace)、硬件工具(pciutils/vulkan-tools) |
| `env/dev`    | `home/env/dev/`   | pdshell devShell 定义文件（每语言一目录，由 `flake.nix` 的 `devShells` 输出加载） |

`env/base` 提供的是**始终可用**的全局工具，不依赖 devShell 激活。`env/dev` 中的定义仅在 `nix develop` 或 `just devenv-*` 时生效。

**devShell 定义约定（env/dev/<lang>/default.nix）：**

```nix
# 每个文件返回一个 attrset，key 为 shell 名称
{ pkgs, inputs, shared, dev, ... }: {
  # (readonly) 默认变体 — 对应 devShells.<arch>.<lang>
  default = {
    shell = "zsh";                    # 进入时使用的 shell
    buildInputs = with pkgs; [ ... ]; # 运行时依赖
    nativeBuildInputs = with pkgs; [ ... ]; # 构建时依赖
    preInputsHook  = '' ... '';       # 依赖注入前
    postInputsHook = '' ... '';       # 依赖注入后（导出 CC/CXX/GOPROXY 等）
    preShellHook   = '' ... '';       # 进入 shell 时（最先）
    postShellHook  = '' ... '';       # 进入 shell 时（最后，欢迎信息）
  };

  # (custom) 可选变体 — 对应 devShells.<arch>.<lang>-<variant>
  machine = {
    shell = "zsh";
    combinFrom = [ dev.c dev.python ]; # 合并其他语言环境
    postInputsHook = '' export LD_LIBRARY_PATH="..."; '';
  };
}
```

`combinFrom` 字段由 pdshell 引擎处理，将多个语言环境的 `buildInputs`、`nativeBuildInputs` 和所有钩子合并为单一 `mkShell`。



`shared.orc` 是针对纯粹 config lib 的操作库, 提供了 wallust 主题动态注入的核心机制，用于在 Home Manager activation 阶段将动态生成的配色文件（wallust 输出）复制到相应的配置目录：

```nix
# 典型用法（以 waybar 为例）
waybarResult = shared.orc.mergeHomeFiles (
  shared.orc.listFilesRecursive inputs.waybar-config ""
) [
  { include = [ "wallust/colors-waybar.css" ];
    emitter = "copy";
    destPrefix = ".config/waybar"; }
];

# activation hook 中注入
home.activation.waybarWallust = lib.hm.dag.entryAfter [ "writeBoundary" ] waybarResult.activation;
```

受 orc 管理的组件：waybar · rofi · swaync · kitty · cava · quickshell · hyprland

### 6. 外部配置仓库（flake=false inputs）

所有工具配置以独立 Git 仓库形式引入，由 Home Manager 在激活时写入 `~/.config/<app>/`：

| flake input            | 目标路径                                            |
| ---------------------- | --------------------------------------------------- |
| `nvim-config`          | `~/.config/nvim/`                                   |
| `emacs-config`         | `~/.config/emacs/`                                  |
| `vscode-config`        | `~/.config/Code/User/`                              |
| `starship-config`      | `~/.config/starship.toml`                           |
| `fastfetch-config`     | `~/.config/fastfetch/`                              |
| `wezterm-config`       | `~/.config/wezterm/`                                |
| `kitty-config`         | `~/.config/kitty/`                                  |
| `tmux-config`          | `~/.config/tmux/`                                   |
| `mpv-config`           | `~/.config/mpv/`                                    |
| `hypr-config`          | `~/.config/hypr/`                                   |
| `niri-config`          | `~/.config/niri/`                                   |
| `rofi-config`          | `~/.config/rofi/`                                   |
| `swaync-config`        | `~/.config/swaync/`                                 |
| `wallust-config`       | `~/.config/wallust/`                                |
| `waybar-config`        | `~/.config/waybar/`                                 |
| `wlogout-config`       | `~/.config/wlogout/`                                |
| `quickshell-config`    | `~/.config/quickshell/`                             |
| `input-overlay-config` | `~/.config/obs-studio/plugin_config/input-overlay/` |

---

## CI/CD 完整执行流

### 概念：为什么 Nix 配置需要 CI/CD

每次变更 nix-config 都等价于声明一个新的系统状态。CI 的核心价值是：

1. **求值检查** — 捕获 Nix 语法错误和类型错误（早于 nixos-rebuild 失败）
2. **构建验证** — 确认所有 derivation 可以成功构建
3. **Secret 完整性** — 验证加密文件结构正确、sops-nix 能成功挂载
4. **跨平台一致性** — 验证 NixOS / Linux / macOS / WSL 配置的求值正确性

### Pipeline 总览

```
Push / PR
    │
    ├─► [STAGE 1: Lint & Evaluate]     快速反馈（< 2 min）
    │       ├── nix flake check
    │       ├── nixfmt --check
    │       ├── statix check
    │       └── deadnix check
    │
    ├─► [STAGE 2: Build]               构建验证（10–30 min）
    │       ├── nixos-rebuild dry-run .#<username>-nixos
    │       ├── home-manager dry-run .#<username>@nixos
    │       └── nix build .#devShells.x86_64-linux.*  (key shells)
    │
    ├─► [STAGE 3: Security]            安全审计（5 min）
    │       ├── sops secrets validate
    │       ├── deadnix (dead code)
    │       └── vulnix (CVE scan, optional)
    │
    └─► [STAGE 4: Deploy] (main only)  部署（手动触发 / auto on tag）
            ├── nixos-rebuild switch
            └── home-manager switch
```

### 本地预检清单（push 前执行）

```bash
# 1. 格式化
nix run nixpkgs#nixfmt-rfc-style -- flake.nix shared.nix lib/ nixos/ home/

# 2. 全量静态检查
nix flake check --no-build

# 3. 求值关键输出（快速验证）
nix eval .#nixosConfigurations.kilig-nixos.config.system.stateVersion

# 4. dry-run 构建
nix build .#nixosConfigurations.kilig-nixos.config.system.build.toplevel \
  --dry-run --no-link 2>&1

# 5. 验证 secret 文件
find secrets/chipr -name "*.yaml" -exec grep -q "sops:" {} \; -print

# 6. 本地 sops 验证（需要 age 私钥）
sops decrypt secrets/chipr/nixos/core/base/user/kilig/password.yaml
```

### 部署工作流

```
开发机 (本地)                        生产机 (NixOS)
    │                                      │
    ├── 编辑 *.nix                          │
    ├── nix flake check --no-build         │
    ├── git push → CI (GitHub Actions)     │
    │       └── lint + build dry-run       │
    │           + security audit           │
    │                                      │
    └── [CI 通过后]                         │
        ├── SSH 到目标机                    │
        │   或在目标机上执行：                │
        │                                  │
        │   # 拉取最新配置                   │
        │   cd ~/.config/nix-config        │
        │   git pull                       │
        │                                  │
        │   # 重建系统                      │
        │   sudo nixos-rebuild switch \    │
        │     --flake .#kilig-nixos        │
        │                                  │
        │   # 重建用户环境                   │
        │   home-manager switch \          │
        │     --flake .#kilig@nixos        │
        │                                  │
        └── 验证服务状态                     │
            systemctl status sops-*        │
            just sops-chipr-read-mongodb   │
```

### 回滚策略

```bash
# 列出可用系统世代
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# 回滚到上一代
sudo nixos-rebuild switch --rollback

# 回滚到指定世代
sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation <N>
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

---

## justfile 命令参考

### 全局

```bash
# 完整初始化（新机器），<username> 是唯一需要提供的参数
just init <username>            # shared-generate → hardware-generate → sops-init; 后续执行 just sops-*

# POST-BOOTSTRAP（shared.nix 已存在）
just sops-init                  # 仅初始化 sops 基础设施
just sops-plan-create-all       # 生成明文模板参考
just sops-rules-regen           # 重建 .sops.yaml 规则
```

### shared — 策略层生成

```bash
just shared-generate <username>  # 从模板生成 shared.nix（唯一合法写入方式）
just shared-show-username        # 显示当前 shared.nix 中的用户名（诊断）
just shared-validate             # 验证模板占位符存在
```

### hardware — 硬件配置

```bash
just hardware-generate           # 生成 nixos/core/base/hardware.nix（首次或硬件变更后）
just hardware-show               # 显示当前 hardware.nix 内容
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
just devenv-create-all                      # 创建所有已知环境（含复合变体）
just devenv-delete-all                      # 删除所有 profile（强制重建用）
just devenv-show                            # 列出 flake 中所有可用 devShell
just devenv-list                            # 树状显示已创建 profile
```

### sops — 密钥与加密

```bash
# ── BOOTSTRAP（需要先 just shared-generate <username>）─────────────────────
just sops-init              # 目录 + 密钥 + 规则（从 shared.nix 读取用户名）
just sops-init-with-plan    # 同上 + 生成所有明文模板

just sops-rules-regen       # 重新生成 .sops.yaml（密钥轮转后）
just sops-plan-create-all   # 生成所有明文模板实例（bootstrap 参考）

# ── POST-BOOTSTRAP（路径由 shared.nix 提供，无需 NIXOS_USERNAME）──────────
just sops-chipr-create-userpwd      # 加密用户系统密码（mkpasswd sha-512）
just sops-chipr-create-nix          # 加密 GitHub access token
just sops-chipr-create-mongodb      # 加密 MongoDB 密码
just sops-chipr-create-mysql        # 加密 MySQL root + 用户密码
just sops-chipr-create-postgresql   # 加密 PostgreSQL 密码
just sops-chipr-create-redis        # 加密 Redis 密码
just sops-chipr-create-all          # 交互式加密所有 secret（按顺序）

just sops-chipr-read-userpwd        # 解密显示用户密码
just sops-chipr-read-nix            # 解密显示 GitHub token
just sops-chipr-read-mongodb        # 解密显示 MongoDB 密码
just sops-chipr-read-mysql          # 解密显示 MySQL 密码（root + user）
just sops-chipr-read-postgresql     # 解密显示 PostgreSQL 密码
just sops-chipr-read-redis          # 解密显示 Redis 密码

# ── 销毁（细粒度，不可逆）──────────────────────────────────────────────────
just sops-key-show          # 显示 age 公钥
just sops-key-destroy       # 销毁 age 密钥（已加密文件将永久不可读）
just sops-rules-destroy     # 删除 .sops.yaml
just sops-plan-destroy      # 删除所有明文模板实例
just sops-chipr-destroy     # 删除所有加密文件（不可逆）
just sops-destroy-all       # 销毁全部 sops 相关内容（不可逆）
```

---

## 快速开始

### 前置条件

- Nix 2.22+（启用 `nix-command`、`flakes`、`pipe-operators` experimental features）
- 目标平台: NixOS · Linux · macOS · WSL2
- Git（用于克隆配置仓库）

```bash
# 启用 Nix flakes（若未启用）
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes pipe-operators" >> ~/.config/nix/nix.conf
```

如果直接使用本仓库，那么配置已符合。

### 初始化（新机器）

> **注意：** NixOS 首次 build 后，非 `/` 挂载点下的目录会被 NixOS 管理，请将配置放在合适路径。
> 首次 build 如果不是在系统别目录下，由于用户身份未创建等原因，会将其余的 ～/\* 清除。(nixos 本身)
> 后续再次构建不会有此问题

```bash
git clone https://github.com/Redskaber/nix-config /etc/nix-config
cd /etc/nix-config

# 完整初始化（<username> 是唯一需要提供的参数）：
#   1. 从 docs/tmpl/shared.nix.tmpl 生成 shared.nix
#   2. 生成 nixos/core/base/hardware.nix
#   3. 初始化 sops 目录 + age 密钥 + .sops.yaml 规则
just init <username>

# 生成明文 secret 模板参考（可选，用于填写前对照）
just sops-plan-create-all

# 交互式加密写入所有 secret
just sops-chipr-create-all
# 或按需单独执行：
# just sops-chipr-create-userpwd
# just sops-chipr-create-nix
# just sops-chipr-create-mongodb
# ...
```

### 部署

> 在部署之前，如果你了解一些内容或者想自己diy, 可以更新 shared.nix 文件中的配置项。
> 此后所有的修改都对此文件进行

```bash
# NixOS 系统（将 <username> 替换为实际用户名）
sudo nixos-rebuild switch --flake .#<username>-nixos

# Home Manager（NixOS 内）
home-manager switch --flake .#<username>@nixos

# 独立 Home Manager（非 NixOS Linux）
home-manager switch --flake .#<username>@linux
```

### 开发环境

```bash
# 一次性进入（不保存 profile）
nix develop .#rust
nix develop .#python
nix develop .#python-machine

# 持久化 profile（离线可用，下次快速进入）
just devenv-create rust
just devenv-create-from python machine

# 进入已有 profile
just devenv-use rust
just devenv-use-from python machine

# 通过 direnv 自动激活（推荐工作流）
echo "use flake github:Redskaber/nix-config#python-machine" > .envrc
direnv allow
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
vim home/core/app/<name>.nix
# 在 home/core/app/default.nix 的 imports 中添加引用

# CLI 工具
vim home/core/sys/<name>.nix
# 在 home/core/sys/default.nix 的 imports 中添加引用
```

### 添加开发语言环境

```bash
mkdir home/core/dev/<lang>
# 参考 home/core/dev/python/ 的结构实现 default.nix
# pdshell 会自动发现并注册到 devShells.<arch>.<lang>
```

### 添加新 Secret（三步，核心逻辑零改动）

**Step 0** - `nixos/core/srv/db/newdb.nix` impl + `nixos/core/srv/db/default.nix` import

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

**Step 3** — `sops.just` 中添加（共 8 行）：

```just
# sops-plan-create-all 中追加：
@just _sops-plan-gen "nixos.core.srv.db.newdb.user.password"

# 新增加密/解密命令：
sops-chipr-create-newdb:
    @just _assert-shared
    @just _sops-chipr-write \
        "nixos.core.srv.db.newdb.user.password" \
        "NewDB password" \
        "<YOUR_NEWDB_PASSWORD>"

sops-chipr-read-newdb:
    @just _assert-shared
    @just _sops-chipr-read "nixos.core.srv.db.newdb.user.password"
```

`_sops-mkdir`、路径解析、模板定位、加密逻辑 —— **全部零改动**。

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
just sops-destroy-all

# 3. 重新初始化 sops 基础设施
just sops-init

# 4. 重新加密所有 secret（需重新输入）
just sops-chipr-create-all

# 5. 可选：重新生成明文模板参考
just sops-plan-create-all
```

> 若希望复用旧 age key（跳过密钥销毁）：
>
> ```bash
> just sops-plan-destroy && just sops-chipr-destroy && just sops-rules-destroy
> just sops-rules-regen   # 用现有密钥重建 .sops.yaml
> just sops-chipr-create-all
> ```

---

## 依赖图

```
flake.nix
├── nixpkgs (25.11)
│   └── nixpkgs-unstable
├── home-manager (release-25.11)
├── sops-nix                     # secret 管理
├── nix-types                    # enum 类型系统（自建）
├── pdshell                      # devShell 管道引擎（自建）
├── configuration-orchestrator   # wallust 主题注入引擎（自建）
├── nixgl                        # 非 NixOS GL 修复
├── nur                          # 社区包
├── hyprland                     # Wayland WM（最新版）
│   └── hyprland-plugins
├── zen-browser                  # 浏览器
├── wechat                       # 微信（自建 flake）
├── unrpyc                       # RenPy 反编译（自建 flake）
├── cnmplayer                    # 网易云音乐 TUI（自建 flake）
└── *-config (flake=false)       # 各工具配置仓库（外部 Git 源）
    nvim · emacs · vscode · starship · fastfetch · wezterm
    kitty · tmux · mpv · btop · cava · niri · hypr · rofi
    swaync · wallust · waybar · wlogout · quickshell
    input-overlay
```

---

## 路线图

- [ ] CI 全量 build 验证（nixos-rebuild dry-run in CI）
- [ ] 第二台机器测试（验证跨机器可移植性）
- [ ] NixOS 测试套件（关键路径自动化验证）
- [ ] flake inputs 自动更新策略（定时 PR）
- [ ] 惰性模块加载（提升大型配置求值速度）
- [ ] 模块文档自动生成（从 Nix 模块 options 生成）

---

> 每个目录是一个模块，每个模块是一个函数，每次重建是一次纯函数推导。  
> 系统状态完全由 Git 中的声明决定，机器是声明的投影。
