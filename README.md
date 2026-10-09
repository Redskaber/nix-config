# nix-config

> 声明式、可复现、多平台的系统与开发环境管理
>
> 作者: [@Redskaber](https://github.com/Redskaber) · 构建于 Nix Flakes + Home Manager + SOPS-Nix

---

## 目录

1. [预览](#预览)
2. [架构总览](#架构总览)
3. [设计原则](#设计原则)
4. [目录结构](#目录结构)
5. [核心机制](#核心机制)
   - [1. 共享层 — 两阶段初始化](#1-共享层--两阶段初始化)
   - [2. 策略层 — shared.nix 生成机制](#2-策略层--sharednix-生成机制)
   - [3. 开发环境管道 — pdshell](#3-开发环境管道--pdshell)
   - [4. 安全层 — SOPS + Age](#4-安全层--sops--age分层管理)
   - [5. 配置编排器 — orc](#5-配置编排器--orcconfigurationorchestrator)
   - [6. 用户环境层 — home/env](#6-用户环境层--homeenv)
   - [7. 外部配置仓库](#7-外部配置仓库flakefalse-inputs)
   - [8. 提交规范](#8-提交规范--husky--commitlint--commitizen零-node_modules)
6. [CI/CD 完整执行流](#cicd-完整执行流)
7. [测试体系](#测试体系)
8. [justfile 命令参考](#justfile-命令参考)
9. [快速开始 — 从 0 到部署全流程引导](#快速开始--从-0-到部署的全流程引导just-驱动)
10. [secrets 多情景手册（just 全流程）](#secrets-多情景手册just-全流程)
11. [跨平台支持](#跨平台支持)
12. [扩展指南](#扩展指南)
13. [依赖图](#依赖图)
14. [路线图](#路线图)

---

## 预览

<details>
<summary>part tools summary</summary>

![preciew_0](./docs/preview/preview_0.png)

![preciew_2](./docs/preview/preview_2.png)

![preciew_5](./docs/preview/preview_5.png)

![preciew_3](./docs/preview/preview_3.png)

![preciew_1](./docs/preview/preview_1.png)

![preciew_4](./docs/preview/preview_4.png)

![preciew_6](./docs/preview/preview_6.png)

</details>

## 架构总览

系统采用严格的层级化管道架构，每层职责单一、边界明确，依赖方向自上而下单向流动。

```
┌────────────────────────────────────────────────────────────┐
│  ENTRY LAYER  ·  flake.nix                                 │
│  统一入口 · 输入声明 · 协议名映射 · api.inputs             │
│  （目标构造已在 SHARED LAYER 生产，此处只消费成品）        │
└──────────┬──────────────────────────────┬──────────────────┘
           │                              │
┌──────────▼──────────┐       ┌───────────▼──────────────────┐
│  SYSTEM LAYER       │       │  USER LAYER                  │
│  platform/<tag>/    │       │  home/ + platform/<tag>/home │
│    default.nix      │       │  home/default.nix →<arch>.nix│
│  硬件·驱动·安全·服务│       │  应用·开发环境·窗口管理器    │
│  core/ · dm/ · wm/  │       │  core/ · env/ · wm/          │
│  （顶层 = 系统域，  │       │  （目录即域，T5.11）         │
│   T5.11）           │       │                              │
└──────────┬──────────┘       └───────────┬──────────────────┘
           │                              │
           │         ┌────────────────────▼──────────────────┐
           │         │  HOST DISPATCH LAYER  ·  platform/    │
           │         │  平台目录 =目标机描述（target double：│
           │         │  platform 轴选目录，arch 轴选用户域内 │
           │         │  的 payload 行）目录即域（T5.11）：   │
           │         │  顶层 = 系统域（default.nix = 系统海关│
           │         │  有系统形态的平台才有）；home/ = 用户 │
           │         │  域（唯一保留字；home/default.nix =   │
           │         │  HM 海关，有独立门才有）·  文件存在性 │
           │         │  = 能力声明                           │
           │         └────────────────────┬──────────────────┘
           │                              │
┌──────────▼──────────────────────────────▼───────────────────┐
│  SHARED LAYER  ·  lib/shared/                               │
│  两阶段初始化：schema/enum/fn/const → runtime 合成          │
│  目标工厂 targets.nix：hosts/ 清单 → caps 分类 →            │
│  nixos / darwin / standalone-HM 三类 closure 发射器         │
│  （生产端：flake.nix 只写 inherit (targets) …；             │
│   策略 IR 每主机单实例化，T5.10）                           │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  SECRET LAYER  ·  secrets/ + .sops.yaml                     │
│  Age 加密 · SOPS 管理 · 最小权限 · 运行时注入               │
│  TMPL → KEY → RULE → PLAIN → CIPHER → /run/secrets/         │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  TEST LAYER  ·  tests/                                      │
│  6 平面 · 89 tests + pre-commit-check = 90 checks           │
│         · nmt(零VM) + QEMU · CI 自动发现                    │
└─────────────────────────────────────────────────────────────┘
```

**数据流向（管道）：**

```
shared.nix (策略)
    ↓ just shared-generate
lib/shared (两阶段初始化)
    ↓ specialArgs / extraSpecialArgs
lib/shared/targets.nix (目标工厂：hosts/ 清单 → caps 分类 → 发射器)
    ↓ 产出成品 closures
flake.nix → inherit (targets) nixosConfigurations / homeConfigurations / darwinConfigurations
    ↓ 三门分发（发射器纯数据驱动目录引用，语法 v3：目录即域）：
    ↓   nixos 系统门 platform/<tag> → default.nix · darwin 单门 platform/<tag> → default.nix（系统路由+arch 分发，HM 内乘） · HM 门 platform/<tag>/home → home/default.nix（arch 路由）
platform/nixos/{default.nix, home/{default,x86_64-linux}.nix} + core/ dm/ wm/ + home/（模块树；app 树按 app-set 重量级路由：full/lean/none）
    ↓ sops-nix (initrd 阶段)
/run/secrets/ (运行时 secret 挂载)
    ↓ systemd services
运行中的系统
```

## 设计原则

| 原则         | 体现                                                                                                          |
| ------------ | ------------------------------------------------------------------------------------------------------------- |
| **依赖倒置** | `lib/shared` 定义抽象 schema/enum，上层模块依赖抽象接口而非具体实现；`shared` 作为 specialArgs 注入           |
| **管道流**   | `shared.nix → lib/shared → flake → host → nixos/home → modules` 单向数据流，无反向依赖                        |
| **层级化**   | entry / host-dispatch / system / user / shared / secret / test 七层，职责不交叉，层间通过 `shared` 通信       |
| **增量模式** | 每个子目录均为独立模块，可单独启用/禁用；`imports` 列表即模块注册表                                           |
| **策略管理** | `shared.nix` 集中声明 platform · drive · wm · dm · shell · editor 等所有策略选项，单一真相源                  |
| **分发层收敛** | 平台语义只回答一次：`enum.platform` 行携带 `caps` 能力向量与策略载荷（home-prefix · btop · trace-tools），flake 路由与全部叶子读同一张表（`shared.caps.*` / `shared.platform.value.*`）；配置树中零 if-else、零原始 tag 比较（T4.0，借鉴编译器多层管道：后续 pass 查询目标描述，绝不重新词法分析） |
| **状态机**   | `lib/shared/enum.nix` 通过 `nix-types` enum 约束合法状态集合，非法值在求值阶段即报错                          |
| **生命周期** | devShell 四阶段钩子：`preInputsHook → postInputsHook → preShellHook → postShellHook`                          |
| **边界明确** | system layer 不感知用户配置；user layer 不直接操作硬件；host layer 是唯一的平台感知点                         |
| **生成不变** | `shared.nix` 由模板生成（覆盖写入），不可 sed 原地 patch；`.sops.yaml` 同理                                   |
| **数据驱动** | `sops.just` 零硬编码路径，所有 secret 路径运行时从 `shared.nix` 读取；CI checks 按前缀动态发现                |
| **通信协议** | 层间通过 `shared` attrset 传递（`specialArgs`/`extraSpecialArgs`）；`api.inputs` 暴露 flake inputs 供脚本查询 |

---

## 目录结构

```
nix-config/
├── flake.nix               # entry layer: 输入声明 + flake 协议名映射（成品由 lib/shared/targets.nix 生产）
├── shared.nix              # 策略层（由 just shared-generate 生成，禁止手动编辑用户名）
│
├── lib/
│   └── shared/
│       ├── default.nix     # 共享加载器：两阶段初始化（scfpath 可覆盖，支持多机器）
│       ├── targets.nix     # 目标工厂（生产端）：hosts/ 清单 → caps 分类 → 三类 closure 发射器；
│       │                   #   flake.nix 只写 inherit (targets) nixosConfigurations …
│       ├── docs.nix        # 文档工厂（生产端）：export/ 模块 → optionsDoc markdown（侧通道发射器）
│       ├── lang/           # 阶段一 · 语言前端：类型/枚举/schema/验证（无 pkgs）
│       │   ├── default.nix # 阶段一聚合：const + schema + enum + fn + tools + validate
│       │   ├── enum.nix    # 枚举类型：arch / platform / wm / dm / shell / drive-group / editor-set / service-profile 等
│       │   ├── schema.nix  # 结构验证：user / git / rbw / time / i18n / secrets / shared
│       │   ├── fn.nix      # 工具函数：isNixOS · isMacOS · isLinux · isWSL · homeDir · sopsFile · sopsRuntimePath
│       │   ├── const.nix   # 常量：secrets 路径 · 权限模式(0400/0440/0600) · XDG 目录名
│       │   └── tools.nix   # 外部工具库注册：nix-types / orc / pdshell（短路径访问，配置文件解耦 inputs）
│       ├── runtime/
│       │   └── default.nix # 阶段二 · IR 合成：pkgs/upkgs/isNixOS/homeDir/orc/sopsFile/tools 注入
│
├── platform/               # 平台分发层（host-dispatch：目录语法 v3 — 目录即域，T5.11）
│   ├── nixos/              # NixOS 双海关（双活门）：顶层 = 系统域：default.nix = 系统海关
│   │                       #   （core/dm/wm 注册 + hosts facts）；home/ = 用户域：
│   │                       #   home/default.nix = HM 海关（standalone 门，秒级切换/独立
│   │                       #   回滚的策略选择）；home/x86_64-linux.nix = HM payload 行；
│   │                       #   core/{base,drive,exp,sec,srv} · dm/ · wm/；nixpkgs = shared.nixpkgs
│   ├── linux/              # 通用 Linux：目录即用户域——home/default.nix = 唯一海关
│   │                       #   （standalone HM + nixGL(mesa) + genericLinux；无系统形态
│   │                       #   ——顶层无 default.nix 即声明；整个平台目录只有 home/）
│   ├── darwin/             # macOS(nix-darwin)：default.nix = 唯一海关（T5.8 单门折叠：
│   │                       #   hm.darwinModule + hosts facts + home-manager.users 挂载
│   │                       #   = import ./home/${arch.tag}.nix 一体——系统门跨域引用，
│   │                       #   路径可见；home/ 内无 default.nix——HM 非独立门，payload
│   │                       #   行仍驻留，以 module mode 挂载）；home/<arch>.nix = HM payload
│   └── wsl/                # WSL2：home/default.nix = 唯一海关（standalone HM + nixGL +
│                           #   genericLinux + systemd；无系统形态，顶层无 default.nix；
│                           #   整个平台目录即用户域）
│
├── home/                   # 用户层（Home Manager）
│   ├── core/
│   │   ├── base/           # 基础：字体 · i18n(fcitx5) · portal(wm 策略驱动) · XDG
│   │   ├── exp/            # 扩展功能（可选模块）
│   │   │   ├── app/        # GUI 应用（app-set 重量级路由，T5.10： full=全树 / lean=文档·阅读·逆向 / none=仅三选集目录）：
│   │   │   │   ├── browser/    #   浏览器：google-chrome · qutebrowser · w3m
│   │   │   │   ├── dl/         #   下载：baidupcs-go · xunlei · downloader
│   │   │   │   ├── editor/     #   编辑器：nvim · emacs · vscode · zed · kiro · cursor · trae · zcode (AI)
│   │   │   │   ├── fm/         #   文件管理：nemo
│   │   │   │   ├── game/       #   游戏：lutris · minecraft(prismlauncher)
│   │   │   │   ├── im/         #   即时通讯：discord(vesktop) · qq · wechat
│   │   │   │   ├── image/      #   图像：gimp · imagemagick · imv · ghostscript · mermaid-cli · tectonic
│   │   │   │   ├── misc/       #   杂项：showmethekey · codex
│   │   │   │   ├── model/      #   建模：blender
│   │   │   │   ├── music/      #   音乐：mpd · easyeffects · spotify · playerctld · cnmplayer
│   │   │   │   ├── note/       #   笔记：obsidian
│   │   │   │   ├── office/     #   办公：pandoc · pdf · wpsoffice · unoconv
│   │   │   │   ├── re/         #   逆向：ghidra · imhex · cutter · pince · scanmem · avalonia-ilspy
│   │   │   │   ├── reader/     #   阅读：koodo-reader · librum · z-library
│   │   │   │   ├── terminal/   #   终端：wezterm · kitty
│   │   │   │   └── video/      #   视频：kazumi · obs-studio · ani-cli · animeko · viu
│   │   │   └── sys/        # 系统工具：
│   │   │       ├── ai/         #   AI CLI：claude-code · opencode · gemini-cli · kiro-cli · cursor-cli · pi-coding-agent
│   │   │       ├── base/       #   基础 CLI：git · fzf · bat · eza · fd · ripgrep · zoxide · yazi
│   │   │       │               #   atuin · starship · direnv · tmux · rbw · just · jq · yq
│   │   │       │               #   wl-clipboard · cliphist · wl-clip-persist · tealdeer · curl · wget
│   │   │       ├── compat/     #   兼容：appimage-run
│   │   │       ├── fs/         #   文件系统：compress(zip/p7zip/zstd) · duf
│   │   │       ├── media/      #   媒体：ffmpeg · mpv
│   │   │       ├── misc/       #   杂项：cava · cursor(指针主题)
│   │   │       ├── monitor/    #   监控：btop · htop · bottom
│   │   │       └── shell/      #   Shell：zsh(fzf-tab+atuin) · fish(fzf-fish+autopair)
│   │   ├── sec/            # 用户安全：rbw(bitwarden CLI)
│   │   └── srv/            # 用户服务：
│   │       ├── db/         #   数据库客户端工具
│   │       ├── notify/     #   通知：mako
│   │       └── security/   #   安全：gnupg keyring
│   ├── wm/
│   │   ├── hyprland/       # Wayland WM（主力）：hyprland + orc wallust 注入 + 完整主题栈
│   │   │   └── theme/      # quickshell · rofi · swaync · satty · swayosd · wallust · waybar · wlogout · qtct
│   │   ├── niri/           # Wayland WM（备选）：niri + 主题栈
│   │   │   └── theme/      # satty · swaylock · swaync · swayosd · waybar · wlogout
│   │   └── gnome/          # GNOME（骨架）
│   └── env/
│       ├── default.nix     # 仅导入 base（dev 由 flake.nix devShells 加载）
│       ├── base/           # 全局基础包：clang · cmake · rustc · cargo · python312 · nodejs_24
│       │                   # 调试工具：valgrind · strace · ltrace · pciutils · vulkan-tools
│       └── dev/            # pdshell devShell 定义（每语言一目录）
│           ├── c/ cpp/ go/ java/ javascript/ typescript/
│           ├── lisp/ lua/ nix/ python/ re/ rust/ zig/
│           └── default.nix # 复合环境：default(全语言) · cpython(C+C++Python) · godot
│
├── hosts/                  # 多主机支持（per-machine hardware + policy overrides）
│   ├── nixos/              # 默认主机：hardware.nix（nixos-generate-config 生成）+ default.nix
│   ├── vm/                 # 评估级 VM 主机：facter.json + disk.nix（声明式硬件/磁盘事实，T5.12/T5.13）+ shared.nix 策略覆盖
│   ├── wsl/                # WSL 主机：shared.nix（platform=wsl 类翻转）
│   └── darwin/             # darwin 主机：shared.nix（platform=darwin + aarch64-darwin）
│
├── secrets/
│   ├── chipr/              # SOPS 加密文件（提交到 Git；.sops.yaml 管控解密权限）
│   └── plan/               # 明文模板实例（⚠️ 禁止提交 Git，.gitignore 已排除）
│
├── export/
│   ├── nixos/              # 可复用 NixOS 模块（供外部 flake 引用，当前为占位符）
│   └── home/               # 可复用 Home Manager 模块（供外部 flake 引用，当前为占位符）
│
├── overlays/               # nixpkgs overlay：additions(pkgs/) · patches
├── pkgs/                   # 自定义 derivation（当前为占位符）
│
├── tests/                  # 测试层（6 平面，89 tests + 1 pre-commit-check）
│   ├── default.nix         # 统一注册表：Plane 0–5 全部 checks；nixosTest/nmtTest runner
│   ├── test_calc.nix       # Plane 0: Smoke 基线
│   ├── nixos/              # Plane 1: NixOS-Plane（QEMU VM）
│   ├── home/               # Plane 2: HM-Plane（QEMU VM + packages）
│   ├── lib/                # Plane 3: Lib-Plane（纯 Nix eval，QEMU 256 MB minimal）
│   ├── integration/        # Plane 4: Integration-Plane（NixOS + HM 联合）
│   └── nmt/                # Plane 5: nmt-Plane（零 VM，纯 eval，dotfile 断言）
│       ├── default.nix     # buildHomeManagerTest 实现 + 注册表
│       └── home/           # 测试文件（lib.nmt.buildHomeManagerTest）
│
├── scripts/
│   └── just/               # justfile 子模块（单一职责分层）
│       ├── shared.just     # shared.nix 生成（tmpl → generate → overwrite）
│       ├── hardware.just   # NixOS 硬件配置生成
│       ├── flake.just      # flake inputs 依赖管理（含 api.inputs 动态枚举）
│       ├── devenv.just     # 开发环境 profile 管理（pdshell，username 从 shared.nix 读取）
│       ├── sops.just       # Age 密钥 + SOPS 加密生命周期（双域密钥层级 + 动词总表）
│       └── commit.just     # 数据驱动的提交规范部署（基于 commit-config flake input）
│
├── docs/
│   ├── preview/            # 截图预览
│   ├── tests/              # 测试文档：test-matrix.md · nixosTest.md · nmt.md
│   └── tmpl/
│       ├── shared.nix.tmpl # 策略层模板（__USERNAME__ 占位符；提交到 Git）
│       └── sops/           # SOPS secret YAML 模板（镜像路径层级结构）
│           ├── sops-rules.yaml.tmpl
│           └── nixos/      # 模板 YAML 文件（__USERNAME__ 占位符）
│
├── .github/
│   └── workflows/
│       ├── ci.yml          # 6 阶段 CI 流水线（lint → nmt → devshells → security → vm-tests → summary）
│       └── update-flake.yml# 每周日自动更新 flake inputs 并开 PR
│
└── justfile                # 任务自动化入口（ROOT 变量 + import 子模块）
```

---

## 核心机制

### 1. 共享层 — 二阶段初始化

`lib/shared` 解决了 Nix 中"配置依赖 pkgs，pkgs 依赖配置"的循环问题：

```
阶段一 (shared/):  const(常量) + schema(结构定义) + enum(合法状态集合) + fn(工具函数)
                   ↓ 纯 Nix 表达式，不依赖 pkgs，可在求值阶段完整验证
阶段二 (core_shared/): user_shared(shared.nix 用户填充) → core_shared
                   ↓ 注入: pkgs · upkgs · isNixOS · homeDir · orc · sopsFile · sopsUserPath · sopsPath · pdshell · pdshells · mkDevShell
阶段二 (runtime_shared): core_shared(runtime_core) → runtime_shared
                   ↓ 注入: packages · overlays
fullShared = shared(阶段一) ∪ user_shared ∪ runtime_core(阶段二注入) ∪ runtime(阶段二注入)
```

**合并顺序（后者覆盖前者）：**

```nix
# lib/shared/runtime/default.nix
core_shared = shared // user_shared // {
  inherit
    homeDir
    pkgs upkgs orc pdshell
    isNixOS
    sopsFile sopsPath sopsUserPath
  ;
  _user_shared = user_shared; # 原始快照，调试使用
  inherit (pdshell) pdshells mkDevShell;
};
runtime_shared = core_shared // {
  packages    = import "${core_shared.self}/pkgs" { inherit pkgs; };
  overlays    = import "${core_shared.self}/overlays" { shared = core_shared; };
};
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

`runtime/default.nix` 合成后的 `fullShared` 包含以下运行时字段：

| 字段           | 来源         | 说明                                                             |
| -------------- | ------------ | ---------------------------------------------------------------- |
| `pkgs`         | runtime 注入 | 稳定版 nixpkgs（含 overlays + config）                           |
| `upkgs`        | runtime 注入 | unstable nixpkgs（含 allowUnfree）                               |
| `isNixOS`      | runtime 计算 | `platform == nixos`，用于条件模块加载                            |
| `homeDir`      | runtime 计算 | 平台感知的 home 目录（Linux: `/home/<u>`，macOS: `/Users/<u>`）  |
| `orc`          | runtime 注入 | configuration-orchestrator lib（wallust 主题注入）               |
| `pdshell`      | runtime 注入 | pdshell 管道流开发环境构建工具                                   |
| `pdshells`     | runtime 注入 | pdshell.pdshells 的函数别名                                      |
| `mkDevShell`   | runtime 注入 | pdshell.mkDevShell 的函数别名                                    |
| `sopsFile`     | runtime 注入 | `rel → store path`，从 secret REL 推导加密文件路径               |
| `sopsPath`     | runtime 注入 | `rel → /run/secrets/<rel>`，普通 secret 运行时路径               |
| `sopsUserPath` | runtime 注入 | `rel → /run/secrets-for-users/<rel>`，neededForUsers secret 路径 |
| `_user_shared` | runtime 保留 | 原始 user_shared 快照（调试/内省用）                             |
| `packages`     | runtime 注入 | `pkgs` 目录导入的自定义 derivation 集合                          |
| `overlays`     | runtime 注入 | `overlays` 目录导入的 overlays (含 patches)                      |

**工具函数（`shared.fn`）：**

```nix
shared.fn.isNixOS  shared.platform   # → bool
shared.fn.isMacOS  shared.platform   # → bool
shared.fn.isLinux  shared.platform   # → bool
shared.fn.isWSL    shared.platform   # → bool
shared.fn.homeDir  shared.platform shared.user.username  # → "/home/kilig" 或 "/Users/kilig"
shared.fn.sopsFile shared.self shared.const.secrets.chipr "nixos/core/base/user/kilig/password"
shared.fn.sopsRuntimePath shared.const.secrets.forUsersPath "nixos/core/base/user/kilig/password"
shared.fn.sopsRuntimePath shared.const.secrets.runtimePath  "nixos/core/base/nix/users/kilig/github/access-token"
```

**系统常量（`shared.const`）：**

```nix
shared.const.secrets.forUsersPath  # "/run/secrets-for-users"
shared.const.secrets.runtimePath   # "/run/secrets"
shared.const.secrets.chipr         # "secrets/chipr"
shared.const.mode.ownerOnly        # "0400"  r--------
shared.const.mode.groupRead        # "0440"  r--r-----
shared.const.mode.ownerWrite       # "0600"  rw-------
shared.const.xdg.config            # ".config"
shared.const.xdg.data              # ".local/share"
```

随后 `shared` 作为 `specialArgs`/`extraSpecialArgs` 传递给所有 NixOS/Home Manager 模块，模块通过 `{ shared, ... }` 消费。

**`api.inputs` — 脚本可查询的 flake inputs 索引：**

```nix
# flake.nix
api.inputs = inputs;
# 用途：just 脚本动态枚举 inputs，无需硬编码列表
# 示例：
nix eval .#api.inputs --json | jq -r 'keys'
# → ["commit-config", "cnmplayer", "home-manager", "hyprland", ...]

# flake-update-not-sops 利用此接口排除 sops-nix：
nix eval .#api.inputs --json | jq -r 'keys - ["sops-nix"] | join(" ")'
```

### 2. 策略层 — shared.nix 生成机制

`shared.nix` 是整个系统的单一真相源，所有平台相关决策集中于此。

**生成不变（Generate, Don't Mutate）**

```
docs/tmpl/shared.nix.tmpl   手动维护，含 __USERNAME__ 占位符（提交 Git）
    ↓  just shared-generate <username>   (sed 替换 → 覆盖写入)
shared.nix                  生成产物，覆盖写入，不可 sed patch（提交 Git）
    ↓  flake.nix: shared = import ./lib/shared { ... }
fullShared                  运行时合成（pkgs + user_shared + runtime）
    ↓  specialArgs / extraSpecialArgs
nixos/ · home/              通过 { shared, ... } 消费
```

**可配置枚举（lib/shared/lang/enum.nix）：**

| 字段              | 合法值                                                                                                                                                                                                                                                                                                                                        |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `arch`            | `x86_64-linux` · `aarch64-linux` · `x86_64-darwin` · `aarch64-darwin` · `i686-linux`                                                                                                                                                                                                                                                          |
| `platform`        | `nixos` · `linux` · `darwin` · `wsl`                                                                                                                                                                                                                                                                                                           |
| `window-manager`  | `hyprland` · `niri` · `gnome`（每个值携带 `portal` 策略）                                                                                                                                                                                                                                                                                     |
| `display-manager` | `ly` · `gdm` · `sddm` · `lemurs`                                                                                                                                                                                                                                                                                                              |
| `drive-group`     | `intel` · `amd` · `nvidia` · `nvidia-prime` · `amd-nvidia` · `amd-nvidia-prime` · `intel-nvidia` · `intel-nvidia-prime`                                                                                                                                                                                                                       |
| `shell`           | `zsh` · `fish` · `bash`                                                                                                                                                                                                                                                                                                                       |
| `editor`          | `nvim` · `vim` · `code` · `zeditor`                                                                                                                                                                                                                                                                                                           |
| `editor-set`      | `minimal` · `full-ai` · `dev` · `full`（多选路由，携带 `editors` 列表）                                                                                                                                                                                                                                                                  |
| `terminal-set`    | `kitty-only` · `wezterm-only` · `both`（多选路由，携带 `terminals` 列表）                                                                                                                                                                                                                                                                      |
| `browser-set`     | `chrome-only` · `qutebrowser` · `cli-only` · `chrome-qute` · `all`（多选路由，携带 `browsers` 列表）                                                                                                                                                                                                                                           |
| `app-set`         | `full` · `lean` · `none`（目录级路由，T5.10 惰性模块加载：携带 `categories` 列表——主机合并哪些 app 树；browser/editor/terminal 三目录随每行必达（自身由各自 set 剪枝）；`full` 行顺序即模块合并序，闭包哈希指纹锚点，由 enum 测试锁定）                                                                                     |
| `service-profile` | `full-autostart` · `dev-on-demand` · `server-pg-only` · `minimal`（策略携带，控制 db/virt 的 install vs autostart）                                                                                                                                                                                                                             |
| `pointer-cursor`  | `Bibata-Modern-Amber` · `Bibata-Modern-Amber-Right` · `Bibata-Modern-Classic` · `Bibata-Modern-Classic-Right` · `Bibata-Modern-Ice` · `Bibata-Modern-Ice-Right` · `Bibata-Original-Amber` · `Bibata-Original-Amber-Right` · `Bibata-Original-Classic` · `Bibata-Original-Classic-Right` · `Bibata-Original-Ice` · `Bibata-Original-Ice-Right` |
| `version`         | `v25_11`（携带 `{stateVersion, wine, swww, adb}` 策略） · `v26_05`（同构）                                                                                                                                                                                                                                                                          |

`window-manager` 枚举值内嵌 `portal` 策略，`nixos/core/base/portal.nix` 和 `home/core/base/portal.nix` 直接消费：

```nix
# enum.nix 中的结构
hyprland = { portal = { default = [ "hyprland" "gtk" ]; extraPortals = (pkgs: ...); wlr = false; }; };
niri     = { portal = { default = [ "wlr" "gtk" ];      extraPortals = (pkgs: ...); wlr = true;  }; };
gnome    = { portal = { default = [ "gtk" ];            extraPortals = (pkgs: ...); wlr = false; }; };

# 消费侧（portal.nix）
xdg.portal.extraPortals = shared.window-manager.portal.extraPortals pkgs;
xdg.portal.config.common.default = shared.window-manager.portal.default;
```

**`drive-group` 枚举 — 多驱动组合：**

```nix
# nixos/core/drive/default.nix 路由逻辑
imports = map (d: ./${d}.nix) shared.drive.value;
# shared.drive.value = [ "intel" "nvidia" ]  → imports [ ./intel.nix ./nvidia.nix ]
```

**`platform/` 平台分发层 — arch 路由（目录即域，T5.11）：**

```nix
# platform/nixos/home/default.nix（HM 海关；linux/wsl 的 home/default.nix 同语法）
imports = [ ./${shared.arch.tag}.nix ];
# shared.arch.tag = "x86_64-linux" → imports ./x86_64-linux.nix

# platform/nixos/home/x86_64-linux.nix 完整激活点
{ imports = [ ../../../home/core ../../../home/env ../../../home/wm ]; ... }
```

**平台能力表（T4.0 分发层收敛）—— `enum.platform` 即目标描述：**

```nix
# lib/shared/lang/enum.nix：每行回答“该平台是什么”，一处声明
nixos = { caps = { linux-family = true; nixos-system = true; wsl = false; darwin = false; };
          home-prefix = "/home"; btop = pkgs: pkgs.btop.override { … }; … };

# lib/shared/targets.nix 输出路由读同一张表（flake.nix 只消费成品；
# 策略 IR 每主机单实例化——分类器/发射器/命名/别名共读一张表，T5.10）：
nixosHosts  = filter (h: sharedByHost.${h}.caps.nixos-system) hostNames;
darwinHosts = filter (h: sharedByHost.${h}.caps.darwin) hostNames;

# app 树按重量级路由（目录级多选，与 browser/editor/terminal 同构但选树不选叶）：
imports = builtins.map (c: ./${c}) shared.appCategories;

# 叶子只消费已解析事实，不再出现 if-else / 谓词重复推导 / tag 比较：
home.packages = lib.mkIf shared.caps.linux-family (with pkgs; [ gimp ]);
programs.btop.package = shared.platform.value.btop pkgs;   # 策略载荷（同 version.wine 惯例）
home.packages = [ … ] ++ (shared.platform.value.trace-tools shared.upkgs);  # Null-Object 空列表
```

新增平台 = 写一行；新增能力维度 = 加一列（构造即穷尽，如 nix-types match）。
契约测试 `tests/lib/shared/lang/caps.nix` 锁定整张表（真值表 + 策略选择 + 穷尽性）。

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
TMPL LAYER    docs/tmpl/sops/**  bootstrap 基线模板（双渲染模式：user-only 剥除
              host 行 / 直达双 key 渲染 host 行，`# __HOST__` 标记）
              占位符约定: __USERNAME__ + __SECRET_VALUE__（单一，无 per-secret 差异）
    ↓
KEY LAYER     user: age-keygen → ~/.config/sops/age/keys.txt
              host: key-new-host → 仓外交付副本 → 落位二选一：
                    远程服务器 /var/lib/sops-nix/key.txt / 本机合并
                    （key-install-host，age 多 identity）
    ↓
RULE LAYER    .sops.yaml = 策略真值 + 分发层（creation_rules 按域分发收件人，
              alias 携带域载荷 user_*/host_*；bootstrap 模板生成一次，
              此后增量演化——rules-init 对已演化文件拒绝覆盖）
    ↓
REGISTRY      secrets.just::_secrets-registry = 别名表（DATA）:
              alias | dotted-key | prompt | transform —— secret-set/get/
              edit/remove 与 secrets-list 都只是对它的薄遍历
    ↓
PLAIN LAYER   secrets/plan/**   明文实例（禁止提交 Git，bootstrap 参考）
    ↓
CIPHER LAYER  secrets/chipr/**  SOPS 加密（提交 Git，运行时解密）
    ↓
ROTATE LAYER  just secrets-verify / secrets-sync / key-rotate-{user,host}
              （规则即数据：secrets-rotate.sh 将 creation_rules 解析为 IR
              后按序匹配，零域知识硬编码）
    ↓
RUNTIME       initrd 阶段 sops-nix 解密 → /run/secrets/ 或 /run/secrets-for-users/
    ↓
SERVICE       mode=0400/0440 · owner=root/service-user · group=<service-group>
```

**密钥层级状态机（引导即迁移）：**

```
EMPTY ──secrets-init──▶ USER_ONLY ──key-add-host──▶ USER+HOST
EMPTY ──secrets-init <alias> <age1…>──▶ USER+HOST   （直达双 key：
        host 密钥材料先行时，引导即渲染双域，与增量路径字节等价）
USER+HOST ──key-remove（+secrets-sync）──▶ USER_ONLY

host 私钥落位（二选一，交付副本只有一份）:
  远程服务器 → /var/lib/sops-nix/key.txt（host-only 机器）
  本机      → key-install-host 合并进 ~/.config/sops/age/keys.txt
              （个人机同时跑 srv 服务时消费两域：user key 解 user 域，
              host identity 保任硬化后 srv 域与独立恢复路径；age 身份
              文件原生多 identity，sops-nix keyFile 本就指向它）
```

**EMPTY 是仓库的出厂态（fresh clone 即此态）：** `.sops.yaml` 与全部密文
blob **不在仓库里**——它们由 just 流程生成（`secrets-init` / `secret-set`），
用**你自己的** age key 加密后才提交。eval 期对 EMPTY 态宽容
（`lib/shared/lang/validate.nix` 的 resolution pass 只 trace 引导命令；
树上出现任一 blob 后即转严——声明而缺失的 secret 在 eval 期报
「declared but not provided」）。deploy 在 EMPTY 态会在 sops 激活期硬失败
（正确的失败层）。

- **user 域**（`core/base/{user,nix}`）→ 仅 user key；**srv 域**（`core/srv/`）
  → host + user 双 key（详见 `docs/secrets/rotation.md`）。
- 生命周期操作面：`just secrets-guide`（地图）/ `just secrets-status`（审计）/
  `just secrets-list`（别名表 × 状态）/ 动词总表见 rotation.md §4
  （create / update / destroy × key / rules / blob）。
- 从 0 到部署的全流程引导（六 Phase）见[快速开始](#快速开始--从-0-到部署的全流程引导just-驱动)，
  按情景的逐步手册见[多情景手册](#secrets-多情景手册just-全流程)。

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

`secrets.just` 中所有 secret 路径在运行时从 `shared.nix` 读取，别名映射只存
在于一张注册表：

- `_secrets-mkdir` — 遍历所有 `nixos.*` secret 值，`dirname(REL)` → `mkdir -p`
- `_secrets-plan-gen` — 只需 dotted key，路径/模板均自动推导
- `_secrets-encrypt` — 单一通用加密写入器，awk ENVIRON 安全替换（防止密码中 `|` `\` 等字符破坏 sed），原子写入（mktemp + mv）

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

**统一信息源：** 所有阶段均从 `shared.nix` 读取用户名。

| 阶段           | 信息源       | 前置条件                      | 命令集                                                  |
| -------------- | ------------ | ----------------------------- | ------------------------------------------------------- |
| BOOTSTRAP      | `shared.nix` | `just shared-generate` 已执行 | `secrets-init`, `key-new-host`, `key-add-host`          |
| POST-BOOTSTRAP | `shared.nix` | `just shared-generate` 已执行 | `secret-set`, `secret-get`, `secret-edit`, `secrets-list` |
| LIFECYCLE      | `.sops.yaml` | bootstrap 已完成              | `secrets-sync`, `key-rotate-*`, `key-remove`, `secret-remove` |

### 5. 配置编排器 — orc（ConfigurationOrchestrator）

`shared.orc` 是针对纯粹通用型 config lib 的操作库，提供了 config 的可筛选、编辑等能力；如：wallust 主题动态注入机制，用于在 Home Manager activation 阶段将动态生成的配色文件（wallust 输出等）复制到相应的配置目录：

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

### 6. 用户环境层 — home/env

`home/env` 是独立于 `home/core` 的全局运行时环境层，在所有平台的用户域 payload 行（`platform/*/home/<arch>.nix`）中与 `home/core` 并列导入：

```
platform/<platform>/home/<arch>.nix
    imports = [ ../../../home/core  ../../../home/env  ../../../home/wm ]
```

**子层职责：**

| 子层       | 路径             | 说明                                                                                                                                  |
| ---------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `env/base` | `home/env/base/` | 全局基础包：编译器(clang/rustc/cargo)、运行时(python314/nodejs_26)、调试工具(valgrind/strace/ltrace)、硬件工具(pciutils/vulkan-tools) |
| `env/dev`  | `home/env/dev/`  | pdshell devShell 定义文件（每语言一目录，由 `flake.nix` 的 `devShells` 输出加载）                                                     |

**`sys/ai/` — AI CLI 子层：**

`home/core/exp/sys/ai/` 是独立于 `sys/base/` 的 AI 工具子层，仅在 `home/core/exp/sys/` 中导入，包含：

| 工具          | 包名          | 说明                         |
| ------------- | ------------- | ---------------------------- |
| `claude-code` | `claude-code` | Anthropic Claude CLI（代码） |
| `opencode`    | `opencode`    | 开源 AI 编码助手             |
| `gemini-cli`  | `gemini-cli`  | Google Gemini CLI            |
| `kiro-cli`    | `kiro-cli`    | AWS Kiro CLI                 |
| `cursor-cli`  | `cursor-cli`  | Cursor AI 编辑器 CLI         |

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

### 7. 外部配置仓库（flake=false inputs）

所有工具配置以独立 Git 仓库形式引入，由 Home Manager 在激活时写入 `~/.config/<app>/`：

| flake input            | 目标路径                                                                    |
| ---------------------- | --------------------------------------------------------------------------- |
| `nvim-config`          | `~/.config/nvim/`                                                           |
| `emacs-config`         | `~/.config/emacs/`                                                          |
| `vscode-config`        | `~/.config/Code/User/`                                                      |
| `starship-config`      | `~/.config/starship.toml`                                                   |
| `fastfetch-config`     | `~/.config/fastfetch/`                                                      |
| `wezterm-config`       | `~/.config/wezterm/`                                                        |
| `kitty-config`         | `~/.config/kitty/`                                                          |
| `tmux-config`          | `~/.config/tmux/`                                                           |
| `mpv-config`           | `~/.config/mpv/`                                                            |
| `hypr-config`          | `~/.config/hypr/`                                                           |
| `niri-config`          | `~/.config/niri/`                                                           |
| `rofi-config`          | `~/.config/rofi/`                                                           |
| `swaync-config`        | `~/.config/swaync/`                                                         |
| `wallust-config`       | `~/.config/wallust/`                                                        |
| `waybar-config`        | `~/.config/waybar/`                                                         |
| `wlogout-config`       | `~/.config/wlogout/`                                                        |
| `quickshell-config`    | `~/.config/quickshell/`                                                     |
| `qutebrowser-config`   | `~/.config/qutebrowser/`                                                    |
| `fcitx5-config`        | `~/.config/fcitx5/`                                                         |
| `input-overlay-config` | `~/.config/obs-studio/plugin_config/input-overlay/`                         |
| `commit-config`        | `<project>/.cz.toml`、`<project>/commitlint.config.js`、`<project>/.husky/` |

### 8. 提交规范 — Husky + Commitlint + Commitizen（零 node_modules）

提交规范也作为外部配置仓库 `commit-config` 引入（`flake = false`），通过 `scripts/just/commit.just` 实现数据驱动部署，**无需任何 `node_modules`**。主要组件：

- **全局工具**（由 Home Manager 通过 `home.packages` 安装）：`commitlint`、`husky`、`commitizen`。
- **规则与交互配置**：`commitlint.config.js`（定义允许的提交类型）和 `.cz.toml`（供 `cz commit` 使用，类型与 commitlint 完全对齐）。
- **Git 钩子**：`husky/commit-msg` 直接调用全局 `commitlint` 命令，在每次提交时验证信息格式。

**快速部署（适用于任意 Git 仓库）：**

```bash
# 为 nix-config 项目部署规则 + 钩子
just commit-setup

# 为其他项目安装钩子（不复制配置文件）
just commit-husky-install /path/to/repo

# 仅复制 commitlint 和 commitizen 配置到项目
just commit-project-rules /path/to/repo

# 可选：部署全局兜底规则到 ~/.commitlintrc.js ~/.cz.toml
just commit-global-rules
```

所有命令都从 `flake.nix` 的 `api.inputs` 动态获取 `commit-config` 在 Nix store 中的路径，确保完全可复现。修改规则时，更新 `commit-config` 仓库后只需重新运行 `just commit-setup` 即可同步。

### 9. 工具库统一管理 — tools.nix

`lib/shared/lang/tools.nix` 集中注册所有外部工具库，配置文件通过 `shared.tools.<name>` 短路径访问，解耦对 `inputs.<long-name>.lib` 的直接引用：

```
lib/shared/lang/tools.nix
    ├─ nix-types（短别名 nt）    — ADT 系统：enum / match / Option / Result
    ├─ orc-raw                  — configuration-orchestrator（arch-specific，runtime 解析）
    └─ pdshell-raw              — pipeline-driven dev shell manager

配置文件消费方式：
    shared.tools.nix-types.match shared.version { ... }     # 替代 inputs.nix-types.lib.match
    shared.tools.orc.mergeHomeFiles ...                      # 替代 inputs.configuration-orchestrator.lib.${system}
```

### 10. 多主机支持 — hosts/

`hosts/` 目录实现多主机分发，每台机器独立硬件事实 + 可选 `shared.nix` 覆盖。

**机器事实的三个文件（T5.12 + T5.13 — 数据 + 解释器路线）：**

```
hosts/
├── nixos/                   # 默认主机（legacy 形态）
│   ├── default.nix          # 主机入口（imports hardware.nix + overrides）
│   └── hardware.nix         # nixos-generate-config 自动生成（模块形态的机器事实）
└── vm/                       # 评估级第二主机（声明式形态）
    ├── default.nix          # 主机入口（reportPath 一行 + imports ./disk.nix）
    ├── facter.json          # nixos-facter 报告（硬件事实的数据形态，T5.12）
    └── disk.nix             # disko 磁盘布局（磁盘事实的数据形态，T5.13）
```

legacy 形态：hardware.nix 是 nixos-generate-config 探测硬件后**生成的 NixOS 模块**——
fileSystems、initrd 模块、微码全部以 option 赋值硬编码在生成物里。声明式形态按事实
类型分文件：**facter.json 是硬件数据**（标准 facter 报告 schema，version 1），由 nixpkgs
自带的 `hardware.facter` 模块（默认模块表内）解释——initrd 的 virtio 模块集、
`nixpkgs.hostPlatform`（report.system）、guest 处理（virtualisation → qemu 类模块集）
全部从报告派生；**disk.nix 是磁盘数据**（disko.devices 布局声明：分区表、分区用途、
文件系统与挂载点），由 disko 模块解释——`fileSystems`、`swapDevices` 与 BIOS boot 的
`boot.loader.grub.devices` 全部从布局派生。解释器注册位置不同是上游化差异的直接后果：
facter 模块上游化进了 nixpkgs（零 import、零 input）；disko 不在 nixpkgs（已对锁定树
核实），其注册 = `platform/nixos/core/base/disk.nix` 一行 import——**能力归平台结构树，
数据归 hosts/**（与 sops-nix 注册于 core/sec/secret 同一裁决）。数据与解释器分离的
价值与 hosts/ 本身同构：机器事实是前端数据，解释它的能力是后端，主机入口只做一行
接线。

真实机器迁移（在目标机上执行；磁盘布局是重装时机——disko 应用即重分区，数据不可保留）：

```
  1. just hardware-facter    # 生成 hosts/<hostname>/facter.json（root 扫描）
  2. 主机入口：imports = [ ./hardware.nix ] → hardware.facter.reportPath = ./facter.json;
  3. 删除 hardware.nix 中的 initrd/hostPlatform 行；fileSystems 走第 4 步
  4. 写 hosts/<hostname>/disk.nix（声明目标分区表）+ 主机入口 imports ./disk.nix；
     重装时从 installer 运行 just disk-format <hostname>（分区/格式化/挂载，破坏性）
```

vm 的报告是**声明**而非探测产物——VM 的硬件本就是被定义的（QEMU x86_64 guest +
virtio 盘/网卡），报告按标准 schema 写出该形态（kvm 虚拟化、virtio_blk/virtio_net 的
driver_modules、无 vmx/svm 的 vCPU）。报告刻意不列 network_interface：平台的
NetworkManager 策略拥有 DHCP，facter 的 per-interface useDHCP 默认面向 scripted
networking，在 NM 之下会再挂一层 dhcpcd；CONTROLLER（virtio-net）在报告中，
驱动照样进 initrd。同理，vm 的磁盘布局也是声明：GPT + EF02（BIOS boot，grub core.img
的 1MiB staging）+ root ext4 占满余盘——布局中的 EF02 分区就是 disko 派生
`boot.loader.grub.devices = ["/dev/vda"]` 的依据（BIOS 形态的结构化表达），与 facter
报告的 `uefi: false` 互相印证；主机文件里只补齐引导策略对齐（grub on /
systemd-boot off——平台默认面向 UEFI 机器群）。

platform/nixos/default.nix 通过 ../../hosts/${shared.hostName} 动态路由到对应主机（系统海关
挂载 host facts；darwin 的海关同理）。
新增主机只需：

```
  1. mkdir hosts/<new-hostname>
  2. just hardware-facter    # 写入 hosts/<hostname>/facter.json（或 hardware-generate 走 legacy）
  3. 在 shared.nix 修改 hostName
```

### 11. 服务按需启动 — service-profile

NixOS 服务管理有 3 个层次：

| 层次 | 机制 | 持久性 | 谁控制 |
| ------ | ------ | -------- | -------- |
| **安装** | `enable = true` | rebuild 后保持 | nix 配置 |
| **首次自启** | `wantedBy = ["multi-user.target"]` | rebuild 后重新应用 | nix 配置（service-profile） |
| **开机自启** | `systemctl enable/disable` | 跨重启 + 跨 rebuild 持久 | 用户手动 |

`service-profile` enum 控制**安装**和**首次自启**：

```nix
# shared.nix
service-profile = shared.enum.service-profile.dev-on-demand;

# dev-on-demand profile:
#   db.postgresql  = { install = true;  autostart = false; }  # 装但不自启
#   db.mongodb     = { install = false; autostart = false; }  # 不装
#   virt.podman    = { install = true;  autostart = true;  }  # 装且自启

# 配置文件消费（nixos/core/srv/db/postgresql.nix）
services.postgresql.enable = shared.services.db.postgresql.install;
systemd.services.postgresql.wantedBy =
  lib.mkForce (lib.optional shared.services.db.postgresql.autostart "multi-user.target");
```

**关键设计**：`dev-on-demand` 设 `wantedBy = []`，意味着 NixOS **不通过 nix 管理开机自启 symlink**。用户通过 `systemctl` 管理：

```bash
# 立即启动/停止（不持久，重启后失效）
just service-start postgresql         # systemctl start
just service-stop postgresql          # systemctl stop

# 开机自启管理（持久，跨重启 + 跨 rebuild）
just service-enable postgresql        # systemctl enable（重启后自启）
just service-disable postgresql       # systemctl disable（重启后不自启）
just service-is-enabled postgresql    # 检查是否开机自启

# 数据库别名
just db-start postgresql              # = service-start
just db-stop postgresql               # = service-stop
just db-enable postgresql             # = service-enable
just db-disable postgresql            # = service-disable
```

**核心原则**：

- nix 文件只决定"安装"和"build 后首次是否自启"
- 首次决定后，服务状态完全由用户通过 `systemctl` 管理
- **不需要修改 nix 文件 + rebuild 来改变服务运行状态**
- `systemctl enable/disable` 的状态跨重启和跨 rebuild 持久

可选 profile：`full-autostart` / `dev-on-demand` / `server-pg-only` / `minimal`

---

## CI/CD 完整执行流

### 为什么 Nix 配置需要 CI/CD

每次变更 nix-config 都等价于声明一个新的系统状态。CI 的核心价值：

1. **求值检查** — 捕获 Nix 语法/类型错误（早于 nixos-rebuild 失败）
2. **Secret 完整性** — 验证加密文件结构正确，`secrets/plan/` 未被提交
3. **测试覆盖** — 81 个 checks（78 测试 + 3 pre-commit-hooks） 覆盖 nixos/home/lib/integration/nmt 五个平面
4. **自动更新** — 每周日自动更新 flake inputs 并开 PR

### 实际 Pipeline（6 阶段，最大并行）

```
push / PR
    │
    ├─► [STAGE 1: Lint & Evaluate]     静态分析 + 浅层 eval（< 2 min）
    │       ├── nix eval .#formatter.*.name          (formatter 可求值)
    │       ├── nix eval .#devShells.* attrNames     (devShells 非空)
    │       ├── nix eval .#nixosConfigurations attrNames  (结构验证，不触发 sopsFile)
    │       ├── nix eval .#homeConfigurations attrNames
    │       ├── nix eval .#checks.* attrNames + 平面计数
    │       └── statix check .                       (Nix 反模式检查)
    │
    ├─► [STAGE 2: nmt-Plane]           HM dotfile 断言，纯 eval，无 KVM（< 1 min）
    │       └── 动态发现 nmt_* checks → nix build 逐个验证
    │
    ├─► [STAGE 3: devShells dry-run]   devShell 矩阵（并行，与 STAGE 2 同时）
    │       └── rust · python · python-machine · nix · go · cpp · c · typescript · re ...
    │
    ├─► [STAGE 4: Security Audit]      SOPS 完整性审计（并行，与 STAGE 2 同时）
    │       ├── secrets/chipr/*.yaml 必须含 sops: 元数据
    │       ├── secrets/plan/ 不得被 git 追踪
    │       ├── .sops.yaml 含 age: + creation_rules:
    │       └── .nix 文件扫描硬编码 token/password
    │
    ├─► [STAGE 5: VM Tests]            QEMU 测试，按平面并行子矩阵（需 KVM）
    │       ├── smoke        (test_*)        — 基线
    │       ├── nixos        (nixos_*)       — 系统模块
    │       ├── home-lib     (home_* lib_*)  — HM 模块 + lib 纯表达式
    │       └── integration  (integration_*) — NixOS + HM 联合激活
    │
    └─► [STAGE 6: Summary]             汇总报告（always，即使前序失败）
```

> **注意：** CI 不运行 `nix flake check` 对 nixosConfigurations 做深层求值，因为
> `sopsFile` 路径（`secrets/chipr/**.yaml`）在 CI 环境中是独立 store source，
> `--no-build` 下不会被物化，导致 "path is not valid" 错误。
> 改用 `nix eval .#nixosConfigurations --apply builtins.attrNames` 做结构验证。

### 本地预检清单（push 前）

```bash
# 1. 静态检查
nix run nixpkgs#statix -- check .

# 2. 结构验证（无构建，无 sopsFile 触发）
nix eval .#nixosConfigurations --apply builtins.attrNames --json
nix eval .#homeConfigurations  --apply builtins.attrNames --json
nix eval .#checks.x86_64-linux --apply builtins.attrNames --json

# 3. nmt 平面（最快，< 30s，无 QEMU）
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]" \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" --no-link

# 4. devShell dry-run
nix build .#devShells.x86_64-linux.rust --dry-run --no-link

# 5. secret 文件验证
find secrets/chipr -name "*.yaml" | xargs grep -L "^sops:" 2>/dev/null \
  && echo "ERROR: plaintext files found" || echo "OK"
```

### 部署工作流

```
开发机 (本地)                        生产机 (NixOS)
    │                                      │
    ├── edit *.nix                         │
    ├── nix eval ... (structure check)     │
    ├── git push → CI (GitHub Actions)     │
    │       └── 6 stage passes             │
    │                                      │
    └── [CI Pass]                          │
        │   cd ~/.config/nix-config        │
        │   git pull                       │
        │                                  │
        │   sudo nixos-rebuild switch \    │
        │     --flake .#kilig-nixos        │
        │                                  │
        │   home-manager switch \          │
        │     --flake .#kilig@nixos        │
        │                                  │
        └── systemctl status sops-*        │
            just secret-get mongodb        │
```

### 世代管理与回滚

```bash
# 列出可用系统世代
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# 回滚到上一代
sudo nixos-rebuild switch --rollback

# 回滚到指定世代
sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation <N>
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### 自动化更新

每周日 UTC 03:00，`.github/workflows/update-flake.yml` 自动：

1. `nix flake update` 更新所有 inputs
2. 生成 `flake.lock` diff 摘要
3. 开 PR（branch: `automation/update-flake-inputs`，label: `dependencies automated`）

---

## 测试体系

测试套件覆盖 6 个平面，总计 **81 个 checks（78 测试 + 3 pre-commit-hooks）**（计数单一来源：`scripts/sh/test-count.sh`）（2026-05-13）：

| 平面        | 前缀           | 数量   | KVM            | 关注点                         | 典型时长 |
| ----------- | -------------- | ------ | -------------- | ------------------------------ | -------- |
| Smoke       | `test_`        | 1      | QEMU           | 基本系统完整性                 | ~1 min   |
| NixOS       | `nixos_`       | 23     | QEMU           | nixos/\* 模块 + 系统服务       | 2–10 min |
| HM          | `home_`        | 36     | QEMU           | home/\* 包安装 + 运行时行为    | 2–8 min  |
| Lib         | `lib_`         | 3      | QEMU 256MB min | lib/shared 纯 Nix 表达式       | <1 min   |
| Integration | `integration_` | 1      | QEMU full      | NixOS + HM 联合激活            | 5–15 min |
| **nmt**     | `nmt_`         | **15** | **✗ 零 VM**    | HM dotfile 内容断言（纯 eval） | <10 s    |

**nmt-Plane 特点：** 纯 Nix eval，无 QEMU，无 KVM，利用 `scrubDerivations` 将包替换为 `@pkg-name@` 占位符，避免触发真实构建。适合 CI 最快反馈路径。

**nmt vs HM-Plane 互补：**

```
home/core/exp/sys/base/fd.nix
  ├─ nmt_home_core_exp_sys_base_fd     dotfile 内容断言（纯 eval，<10s）
  │    tests/nmt/home/core/exp/sys/base/fd.nix
  │    .config/fd/ignore: .git/ / *.bak 条目
  └─ home_core_exp_sys_base_fd         运行时行为（QEMU VM，~2min）
       tests/home/core/exp/sys/base/fd.nix
       fd --version, fd finds files by pattern
```

**CI 动态发现（无需手动维护列表）：**

```bash
# 按前缀过滤 checks，新增测试自动被 CI 发现
nix eval ".#checks.x86_64-linux" \
  --apply 'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json
```

**运行命令：**

```bash
# 全量（需要 KVM）
nix flake check

# nmt only（最快，无 QEMU）
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]" \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" --no-link

# 单个
nix build .#checks.x86_64-linux.nmt_home_core_base_git -L
nix build .#checks.x86_64-linux.nixos_core_srv_db_postgresql -L
nix build .#checks.x86_64-linux.integration_hm_activation -L
```

**nmt 获取机制：** sourcehut 对 Nix fetcher UA 返回 HTTP 403，因此使用 `github:Redskaber/nmt`（mirror）+ `flake = false`，通过 store path 直接引用。`buildHomeManagerTest` 包装器在 `tests/nmt/default.nix` 中自行实现（nmt 原生不提供此函数）。

详见 [`docs/tests/test-matrix.md`](docs/tests/test-matrix.md) · [`docs/tests/nixosTest.md`](docs/tests/nixosTest.md) · [`docs/tests/nmt.md`](docs/tests/nmt.md)

---

## justfile 命令参考

> 全量动词面共 78 个 recipe，`[group]` 注解分组——`just --list` 给出按组
> 组织的全部入口（bootstrap / secrets / keys / rules / deploy / flake /
> devenv / services / shared / hardware / commit / maintenance）；
> 裸 `just`（无参数）打印 start-here 地图；secrets 侧的生命周期地图从
> `just secrets-guide` 进入。

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
just secrets-init [alias age1…]      # 仅初始化 sops 基础设施（可选直达双 key）
just secrets-plan-create             # 生成明文模板参考
just rules-init                      # 仅当 .sops.yaml 缺失时重建（对已演化文件拒绝）
```

### host — 主机与部署目标（T2.4，数据驱动）

> 主机清单由 hosts/ 目录枚举，flake 自动发现 —— 加机器 = `mkdir hosts/<name>`
>
> - 两个文件，零 flake 改动；这里的 recipe 同样零硬编码。

```bash
just hosts-list                 # 列出全部可求值主机（nixosConfigurations 键）
just home-targets               # 列出全部独立 home-manager 目标（<user>@<host>）

just nixos-switch <host>        # NixOS 切换（= sudo nixos-rebuild switch --flake .#<host>）
just nixos-test <host>          # test 模式（不写 boot 条目，重启即弃）
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

### disk — 磁盘布局应用（T5.13）

```bash
just disk-show <host>          # 只读：求值该主机 disko 布局的推导结果（fileSystems/boot 接线）
just disk-format <host>        # 破坏性：从锁定闭包构建并运行 pinned 分区/格式化/挂载脚本
                               # （重装/installer 场景；extra args 透传，如 --dry-run）
```

### services — 按需服务管理

```bash
# 立即启动/停止（不持久，重启后失效）
just service-start <name>       # systemctl start
just service-stop <name>        # systemctl stop
just service-restart <name>     # systemctl restart
just service-status <name>      # systemctl status

# 开机自启管理（持久，跨重启 + 跨 rebuild）
just service-enable <name>      # systemctl enable（重启后自启）
just service-disable <name>     # systemctl disable（重启后不自启）
just service-is-enabled <name>  # 检查是否开机自启

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
> **仓库出厂态 = EMPTY**：`.sops.yaml` 与密文 blob 由下列动词生成后提交，
> 不携带任何预置密钥材料（见 §4 安全层）。

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
just key-install-host <alias> [src]             # host identity 合并进本机 key 文件（own host，幂等）
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
just dump                      # 导出项目文件树 + 拼接全文到 tmp/（文档/审计用）
```

---

## 快速开始 — 从 0 到部署的全流程引导（just 驱动）

> 六个 Phase，每步都是 just 动词或显式 nix 命令；任何一步不确定时回到
> 对应 guide（`just secrets-guide` / `just --list`）。本节就是"从 0 开始"
> 的完整路径——裸机可循，已有机器可从中间 Phase 进入。

### Phase 0 — 裸机 → Nix + just 就绪

**NixOS**（已内置 Nix；LiveISO 同样自带）：跳到 Phase 1。

**非 NixOS Linux / macOS / WSL2**（只用 home-manager 层）：

```bash
# 安装 Nix（Determinate Systems 安装器，带 flakes 支持开箱即用）
curl -L https://install.determinate.systems/nix | sh -s -- install

# 启用 flakes（官方安装器或已有安装需要手动开启）
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes pipe-operators" >> ~/.config/nix/nix.conf
```

**just 的可用性**（本仓库所有操作面的入口；不全局安装，一次性进入）：

```bash
nix shell nixpkgs#just nixpkgs#git      # 或: nix-shell -p just git
```

> 从这里开始，所有命令都在仓库根目录执行（`just` 的 ROOT 锚定）。

### Phase 1 — 克隆 + 策略与密钥基线

> **注意：** NixOS 首次 build 后，非 `/` 挂载点下的目录会被 NixOS 管理，请将配置放在合适路径。
> 首次 build 如果不是在系统别目录下，由于用户身份未创建等原因，会将其余的 ～/\* 清除。(nixos 本身)
>
> 后续再次构建不会有此问题

```bash
git clone https://github.com/Redskaber/nix-config /etc/nix-config
cd /etc/nix-config
```

**个人机**（user key 单 key 基线）：

```bash
just init <username>
#   = shared-generate（策略真值 shared.nix）
#   + hardware-generate（hosts/<hostname>/hardware.nix 硬件探测）
#   + secrets-init（目录 + user age 密钥 + .sops.yaml 基线）
```

**服务器机**（user + host 双 key 直达引导，两步取代三步）：

```bash
just key-new-host <alias>                # ① 生成 host keypair（仓外交付副本，chmod 400）
just init <username> <alias> <age1…>     # ② 直达 USER+HOST（srv 域双收件人）
# ③ 交付副本 → 目标机 /var/lib/sops-nix/key.txt（chmod 400）后 shred
```

> 已按个人机引导过、想增量接入 host key？走 `just key-add-host` +
> `secrets-sync`（见 `just secrets-guide` 的四步流）。

### Phase 2 — secrets 就绪

```bash
just secrets-plan-create        # 可选：生成明文模板参考（填写前对照）

nix shell nixpkgs#mkpasswd --command just secret-set-all
# 交互式逐项录入（输入即加密，明文不落盘）；或按需单独：
#   just secret-set userpwd             # 用户系统密码（mkpasswd sha-512）
#   just secret-set nix                 # GitHub access token
#   just secret-set mongodb             # ...

just secrets-verify              # 收件人一致性审计（期望全绿，红则按提示修）
just secrets-status              # 三层状态总览（key / rule / blob + 本机 identity）
```

> **个人机同时跑 srv 服务**（dev-on-demand db profile）？Phase 1 用直达双 key
> 引导后，把 host identity 也落位本机：`just key-install-host <alias>`
> ——基线态单把 user key 已够用，但硬化 srv 策略（host-only）与本机独立
> 恢复路径都要求它就位（详见 rotation.md §2b「own host = srv host」）。

### Phase 3 — 首次部署

```bash
just hosts-list                 # 确认主机键（hosts/ 目录数据驱动）
```

**A. 全新 NixOS 机（从 LiveISO 安装）**：

```bash
# 分区 + 挂载后（/ 与 /boot），在目标环境生成硬件配置并安装：
sudo nixos-install --flake /etc/nix-config#<host>
```

**B. 已有 NixOS 系统（接管/切换到本配置）**：

```bash
just nixos-switch <host>       # = sudo nixos-rebuild switch --flake .#<host>
```

**C. 非 NixOS 平台（仅 home-manager 层）**：

```bash
just home-switch <host>         # → <username>@<host>（如 just home-switch wsl）
# macOS: darwin-rebuild switch --flake .#<host>
```

### Phase 4 — 验证与回滚

```bash
just secrets-status             # secrets 三层健康
nixos-rebuild list-generations  # 世代清单（每次 switch 一代）
sudo nixos-rebuild rollback     # 一键回上一代
just nixos-test <host>          # 试验性切换（不写 boot 条目，重启即弃）
```

### Phase 5 — day-2 速查（上线之后）

```bash
# 例行更新（sops-nix 锁版本，防意外破坏解密链）
just flake-update-not-sops && just nixos-switch <host>

# secrets 生命周期（地图: just secrets-guide / 文档: docs/secrets/rotation.md）
just secrets-verify              # CI 同款审计
just key-rotate-user <age1…>     # user key 轮换（三步引导）
just key-rotate-host <age1…>     # host key 轮换（加新→重加密→撤旧）

# 新机器接入 = mkdir hosts/<name> + 两个文件（零 flake 改动）
# 新 secret 声明 = 三层（shared.nix.tmpl / 模板 YAML / 4 行 recipe，见扩展指南）
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

## secrets 多情景手册（just 全流程）

> [快速开始](#快速开始--从-0-到部署的全流程引导just-驱动) 是**线性**的从 0 到部署路径；
> 本节是**按情景**的查阅手册——每个情景独立成立，给出目标、前置、命令、
> 落点状态机位置与验证。所有情景共享同一张地图：`just secrets-guide`。

### 速查表（一条命令一个意图）

| 意图 | 命令 |
| --- | --- |
| 我有哪些秘密 / 缺哪个 | `just secrets-list` |
| 录入 / 改一个秘密 | `just secret-set <alias>` |
| 看一个秘密 | `just secret-get <alias>` |
| 编辑一个秘密 | `just secret-edit <alias>` |
| 全部录入（顺序） | `just secret-set-all` |
| 谁能解密（钥匙/规则总览） | `just secrets-status` |
| 规则 ↔ 密文一致性 | `just secrets-verify` |
| 改了规则后对齐密文 | `just secrets-sync` |
| 生命周期地图 | `just secrets-guide` |

### 情景 1 — 个人机 day-one（从 0，user 单 key）

**目标**: 全新个人机，secrets 从无到有。**前置**: Nix + just 就绪（快速开始 Phase 0）。

```bash
just init <username>     # shared.nix + hardware.nix + 密钥/规则基线（生成 user age key）
just secret-set-all      # 逐项录入（输入即加密；userpwd 需要 mkpasswd —— 见下）
just secrets-verify      # 期望: all secret blobs match the .sops.yaml hierarchy
```

```bash
# userpwd 走 mkpasswd sha-512，一次性进入工具环境再录入：
nix shell nixpkgs#mkpasswd --command just secret-set-all
```

**落点**: `USER_ONLY`。**验证**: `just secrets-list`（全部 `set`）+
`just key-show`（把公钥记录到密码管理器；**备份 `~/.config/sops/age/keys.txt`——
它是你个人域唯一的解密钥匙**）。**提交**: `.sops.yaml`（公钥，可入库）与
`secrets/chipr/**`（你的 key 加密的密文）。

### 情景 2 — 个人机同时跑 srv 服务（一台机器，user + host 双 key）

**目标**: dev-on-demand db profile 的个人机——同一台机器消费 user 域与
srv 域。这是「own host = srv host」分支：host 私钥也落位**本机**
（age 身份文件原生多 identity，`sops-nix` 的 `keyFile` 本就指向它）。

```bash
just key-new-host <alias>             # ① 生成 host keypair（仓外交付副本 ~/Downloads）
just init <username> <alias> <age1…>  # ② 直达 USER+HOST（①打印的公钥传入）
just secret-set-all                   # ③ 录入（srv 域 blob 双收件人）
just key-install-host <alias>         # ④ host identity 合并进本机 key 文件
shred -u ~/Downloads/host-<alias>.age # ⑤ 本机已持有 identity，销毁交付副本
```

已按情景 1 引导过？增量接入：`just key-add-host <alias> <age1…>` →
`just secrets-sync`（存量 blob 迁移到双收件人）→ `key-install-host`。

**落点**: `USER+HOST`（本机持双 identity）。**验证**: `just secrets-status`
（local identities 应列出两把）+ `just secret-get postgresql`（srv 域可解）。

**为什么要 ④**: 基线态单把 user key 已可解 srv 域；但两条路都要求 host
identity 就位——**硬化策略**（srv 收件人轮换到 host-only）后本机只有
user key 将解不开 srv blob；**独立恢复路径**（user key 在其它机器失陷时，
本机 host identity 仍是 srv 域有效解密方）。

### 情景 3 — 接入远程服务器

**目标**: 服务器（headless host）能自主解密 srv 域，无需人在场。

```bash
just key-new-host <alias>            # ① 服务器 keypair（你操作机上生成）
just key-add-host <alias> <age1…>    # ② 公钥接线进 .sops.yaml（srv 域）
just secrets-sync                    # ③ 存量 blob 迁移到双收件人
# ④ 交付: host-<alias>.age → 服务器 /var/lib/sops-nix/key.txt（chmod 400）
#    然后 shred 交付副本 —— 目标机唯一持有
```

**落点**: `USER+HOST`。**验证**: 服务器上 `sudo sops -d
secrets/chipr/<任一srv>.yaml`（或部署后看 sops-nix 激活）。
**注意**: 服务器**不需要**（也不应有）user key——它只解 srv 域。

### 情景 4 — 第二台个人机（既有 user key 导入）

**目标**: 新个人机解密既有 user 域。**前置**: 情景 1 的 key 备份在手。

```bash
# ① 恢复 user key（备份的 keys.txt → 新机器同路径，chmod 400）:
mkdir -p ~/.config/sops/age && cp <backup>/keys.txt ~/.config/sops/age/
chmod 400 ~/.config/sops/age/keys.txt

just init <username>                 # ② 基线（检测到 key 已存在则跳过生成）
just secrets-verify                  # ③ 既有 blob 直接收件人一致
just secret-get nix                  # 验证: user 域可解
```

**注意**: `secrets-init` 幂等——key 文件已存在时不覆盖（私钥不可恢复，
永不覆写）。规则基线渲染会用**本机现有**公钥（`age-keygen -y` 读取）。

### 情景 5 — user key 轮换

**目标**: 定期轮换 / 疑似暴露的预防性轮换。

```bash
age-keygen -o /tmp/new-user.age 2>/dev/null          # ① 新 keypair（仓外）
just key-rotate-user $(age-keygen -y /tmp/new-user.age)
# ② 脚本打印三步引导:
#    1/3 替换 .sops.yaml 中 user_* 公钥（示例给出精确行）
#    2/3 just secrets-sync        # 全量重加密到新收件人
#    3/3 提交。旧密文在 git 历史中仍可被旧 key 解——接受该暴露或重写历史
# ③ 新 key 落位本机（替换 ~/.config/sops/age/keys.txt，旧文件备份后销毁）
```

**落点**: `USER_ONLY`/`USER+HOST` 不变（换钥不换层级）。**验证**:
`just secrets-verify` + 其它个人机重复情景 4。

### 情景 6 — host key 轮换 / 撤销

**目标**: 服务器迁移、host 疑似暴露、退役。

```bash
# 轮换（先加后撤，无裸窗口）:
just key-new-host <new-alias>
just key-rotate-host $(just key-show-host <new-alias>)
#    四步引导: key-add-host → secrets-sync → key-remove <old> → secrets-sync

# 撤销（退役某台 host）:
just key-remove <alias>     # 接受短名（lab → host_lab）或全名
just secrets-sync           # 失效 key 从此解不开新密文
```

**验证**: `just secrets-status`（keys 区不再列出该别名）+ `secrets-verify`。

### 情景 7 — 疑似失陷应急

1. **撤销**: `just key-remove <alias>` → `just secrets-sync`（失陷 key
   从此解不开新 blob；sops 的 metadata MAC 使旧 key 持有者无法伪造新 blob）。
2. **另一域评估**: user 域与 srv 域爆炸半径隔离（§4 安全层）——按失陷的
   是哪个域决定动作面。
3. **数据层轮换**: 配置层轮换不替代数据层——数据库侧再执行
   `ALTER USER … PASSWORD`。
4. **git 历史**: 旧密文仍在历史中可解——接受暴露或重写历史
   （rotation.md §compromise 的权衡）。

### 情景 8 — 新增一个 secret（三层，配置层是真值）

```bash
# ① shared.nix.tmpl 声明 dotted key（重新生成 shared.nix）:
#    nixos.core.srv.db.newdb.user.password = "nixos/core/srv/db/newdb/users/__USERNAME__/password";
# ② 模板 YAML: docs/tmpl/sops/nixos/core/srv/db/newdb/users/__USERNAME__/password.yaml
#    （叶子键 = 路径末段；占位符 __SECRET_VALUE__ / __USERNAME__）
# ③ 注册表一行: secrets.just::_secrets-registry
#    'newdb|nixos.core.srv.db.newdb.user.password|NewDB password|plain'
just shared-generate <username> && just secret-set newdb && just secrets-verify
```

### 情景 9 — 销毁 / 退役

```bash
just secret-remove <alias>     # 单个密文（shared.nix 声明另行移除——配置层真值）
just secrets-plan-destroy     # 全部明文参考实例
just rules-destroy            # .sops.yaml
just key-destroy              # 本机 user key 文件（不可逆！blob 仍在仓库）
just secrets-destroy-all      # 以上全部（明文实例+密文+规则+key 文件）
```

> 销毁 key 文件不影响仓库中的密文（它们等着**某把**合法私钥来解）；
> 销毁密文前确认 shared.nix 中的声明也已退役，否则 eval 期
> 「declared but not provided」会如实报错。

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
vim home/core/exp/app/<class>/<name>.nix
# 在 home/core/exp/app/<class>/default.nix 的 imports 中添加引用

# CLI 工具
vim home/core/exp/sys/<class>/<name>.nix
# 在 home/core/exp/sys/<class>/default.nix 的 imports 中添加引用
```

### 添加开发语言环境

```bash
mkdir home/env/dev/<lang>
# 参考 home/env/dev/python/ 的结构实现 default.nix
# pdshell 会自动发现并注册到 devShells.<arch>.<lang>
```

### 添加新 Secret（三步，核心逻辑零改动）

**Step 0** — `nixos/core/srv/db/newdb.nix` impl + `nixos/core/srv/db/default.nix` import

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
├── wechat                       # 微信（自建 flake）
├── unrpyc                       # RenPy 反编译（自建 flake）
├── cnmplayer                    # 网易云音乐 TUI（自建 flake）
├── nmt                          # HM dotfile 测试框架（flake=false, GitHub mirror）
├── commit-config                # 提交规范（commitlint + commitizen + husky 规则）
└── *-config (flake=false)       # 各工具配置仓库（外部 Git 源）
    nvim · emacs · vscode · starship · fastfetch · wezterm
    kitty · tmux · mpv · btop · cava · niri · hypr · rofi
    swaync · wallust · waybar · wlogout · quickshell · qutebrowser
    input-overlay · fcitx5
```

---

## 路线图

- [x] CI 全量 build 验证（nmt-Plane + QEMU VM tests，6 阶段流水线）
- [x] NixOS 测试套件（90 checks = 89 tests + 1 pre-commit-check〔内含 nixfmt/statix/deadnix 三钩子〕，6 个测试平面）
- [x] flake inputs 自动更新策略（定时 PR，每周日）
- [x] platform/ 平台分发层（nixos · linux · darwin · wsl，arch 路由）
- [x] api.inputs 暴露（just 脚本动态枚举 inputs，零硬编码）
- [x] AI CLI 工具集成（claude-code · opencode · gemini-cli · kiro-cli · cursor-cli）
- [x] kiro 编辑器集成（home/core/exp/app/editor/kiro.nix）
- [x] nmt mirror 解决方案（sourcehut 403 规避，buildHomeManagerTest 自实现）
- [x] sops 数据驱动架构（零硬编码路径，phase-aware 信息源分离）
- [x] secrets just 生命周期重设计（T5.0：仓库出厂态 = EMPTY——`.sops.yaml` 与密文 blob 全部由 just 流程生成（`secrets-init`/`secret-set`）后入库，不携带预置密钥材料；动词面按三对象重组 secret-*/key-*/rules-* + 注册表驱动（12 个 per-secret recipe → 1 张别名表）；`just`（裸）= start-here 地图 + `[group]` 分组的 `just --list`；eval 期 resolution pass 对 EMPTY 态宽容（零 blob → trace 引导，≥1 blob → 严格 declared-but-not-provided）+ fixture 化契约测试；CI security 全步骤 EMPTY 容忍；README 多情景手册（9 情景 × 速查表）+ 全流程文档同步）
- [x] tools.nix 工具库统一管理（nix-types / orc / pdshell 短路径访问）
- [x] hosts/ 多主机支持（per-machine hardware.nix + overrides）
- [x] service-profile 按需启动（install vs autostart 分离，dev-on-demand / full-autostart / server-pg-only / minimal）
- [x] editor-set / terminal-set / browser-set 集合路由（多选路由模式）
- [x] version 策略携带（variant 携带 {stateVersion, wine, swww} 策略）
- [x] shellIntegrations 统一（runtime 计算，8 个 base 模块复用）
- [x] match 穷尽性（nix-types lib.match 替代手写 if）
- [x] 分发层收敛（T4.0：enum.platform 能力表 caps + 策略载荷；全树消灭叶子级 if-else/谓词重复推导/tag 比较；schema 嵌套默认值物化修复；变异验证 ×2 + 六配置求值级行为保持——home×3/darwin drv 字节一致）
- [x] 入口清爽化（T5.1：flake.nix 只保留输入声明 + 协议名映射；主机清单→caps 分类→closure 发射器全部移入 lib/shared/targets.nix 生产端——编译器后端 pass；根目录 darwin/ 并入 platform/darwin/system.nix，host-dispatch 层一个平台一个目录；pre-commit 配置移入 tests/pre-commit.nix）
- [x] 中间层命名收敛（T5.2：lib/shared/shared → lib/shared/lang——语言前端层（类型/枚举/schema/验证，无 pkgs），消除路径重复命名；三段式镜像编译器管道：lang（frontend）→ runtime（IR 合成）→ targets.nix（codegen）；`shared` 逻辑名保持为全树稳定线协议，测试镜像与 check 名同步 lib_shared_lang_*）
- [x] pre-commit-hooks（nixfmt + statix + deadnix 自动检查）
- [x] services.just 按需启动命令（service-start/stop/status + db-start/stop/list）
- [ ] 第二台机器测试（验证跨机器可移植性，scfpath 多机器场景）（T2.3-T2.5：hosts/vm 策略链已通，双机求值级验收完成；boot 级验收待 KVM/真实环境）
- [x] 惰性模块加载（T5.10：两 pass 一 commit——**Pass A 策略 IR 单实例化**（分发层 CSE：mkShared 每 flake 求值 ~23 次〔3×byCap 分类 × 每主机 + 三类发射器 + homeConfigurations 命名 + 遗留别名重发射 + flake 基实例〕；单进程全输出求值 4GB 沙箱仍 OOM〔六 OS 级模块宇宙驻留的内存地板，非策略实例问题〕）
- [x] 模块文档自动生成（从 Nix 模块 options 生成）（三 closure + 双 HM drv 哈希字节级一致验证）
- [x] darwin 发射器装配内聚
- [x] 平台架构完成：nixos 系统树归位
- [x] darwin 单门折叠
- [x] 平台目录语法 v2：文件名即域
- [x] 平台目录语法 v3：目录即域
- [x] export/ 模块完善
- [x] nixos-facter 替代 nixos-generate-config（声明式硬件发现）
- [x] disko 声明式磁盘分区（替代 hardware.nix 里的 fileSystems 硬编码）
- [ ] impermanence 实验性 ephemeral root（btrfs subvol rollback）
- [ ] nix-types 上游贡献（schema pattern matching 模式文档化）
- [x] Option/Result 类型化错误处理（T4.1：secret 路径校验用 result.andThen —— nix-types Result 铁路〔shared/validate.nix〕：形状检查前置 pass 折叠 + 文件系统存在性 resolution pass + unwrapOrElse 单一边界 throw；声明而缺失的 secret 在 eval 期报「declared but not provided」；变异验证 ×2 + home×3/darwin drv 字节一致）
- [x] 可观测性（prometheus exporters + loki 日志 + grafana dashboard）（T3.4：service-profile 携带 monitor 策略，三档 profile 求值级验收 + nixos_core_srv_monitor_policy 测试）
- [x] 健康检查（数据库服务加 systemd HealthCheck）（T3.4：双层——Restart 自愈兜底 + 30s liveness timer 探活，60s 可观测窗口，变异测试验证）

---

> 每个目录是一个模块，每个模块是一个函数，每次重建是一次纯函数推导。
> 系统状态完全由 Git 中的声明决定，机器是声明的投影。
