# nix-config

> 声明式、可复现、多平台的系统与开发环境管理
>
> 作者: [@Redskaber](https://github.com/Redskaber) · 构建于 Nix Flakes + Home Manager + SOPS-Nix + nix-darwin + disko

---

## 目录

1. [预览](#预览)
2. [架构总览](#架构总览)
3. [设计原则](#设计原则)
4. [目录语法 — 平台分发层的文法](#目录语法--平台分发层的文法)
5. [目录结构](#目录结构)
6. [核心机制](#核心机制)
   - [1. 共享层 — 两阶段初始化](#1-共享层--两阶段初始化)
   - [2. 策略层 — shared.nix 生成机制](#2-策略层--sharednix-生成机制)
   - [3. 分发层 — targets.nix 目标工厂](#3-分发层--targetsnix-目标工厂)
   - [4. 开发环境管道 — pdshell](#4-开发环境管道--pdshell)
   - [5. 安全层 — SOPS + Age](#5-安全层--sops--age分层管理)
   - [6. 配置编排器 — orc](#6-配置编排器--orcconfigurationorchestrator)
   - [7. 用户环境层 — home/env](#7-用户环境层--homeenv)
   - [8. 外部配置仓库](#8-外部配置仓库flakefalse-inputs)
   - [9. 提交规范](#9-提交规范--husky--commitlint--commitizen零-node_modules)
   - [10. 多主机支持 — hosts/](#10-多主机支持--hosts)
   - [11. 服务按需启动 — service-profile](#11-服务按需启动--service-profile)
7. [CI/CD 完整执行流](#cicd-完整执行流)
8. [测试体系](#测试体系)
9. [justfile 命令参考](#justfile-命令参考)
10. [快速开始 — 从 0 到部署全流程引导](#快速开始--从-0-到部署的全流程引导just-驱动)
11. [secrets 多情景手册（just 全流程）](#secrets-多情景手册just-全流程)
12. [跨平台支持](#跨平台支持)
13. [扩展指南](#扩展指南)
14. [依赖图](#依赖图)
15. [已知边界与设计债](#已知边界与设计债)
16. [路线图](#路线图)

---

## 预览

<details>
<summary>part tools summary</summary>

![preview_0](./docs/preview/preview_0.png)

![preview_2](./docs/preview/preview_2.png)

![preview_5](./docs/preview/preview_5.png)

![preview_3](./docs/preview/preview_3.png)

![preview_1](./docs/preview/preview_1.png)

![preview_4](./docs/preview/preview_4.png)

![preview_6](./docs/preview/preview_6.png)

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
│  default.nix        │       │  home/default.nix → <arch>.nix│
│  硬件·驱动·安全·服务│       │  应用·开发环境·窗口管理器    │
│  core/ · dm/ · wm/  │       │  core/ · env/ · wm/          │
│  （顶层 = 系统域，  │       │  （目录即域，T5.11）         │
│   T5.11）           │       │                              │
└──────────┬──────────┘       └───────────┬──────────────────┘
           │                              │
           │         ┌────────────────────▼──────────────────┐
           │         │  HOST DISPATCH LAYER  ·  platform/    │
           │         │  平台目录 = 目标机描述（target double：│
           │         │  platform 轴选目录，arch 轴选用户域内 │
           │         │  的 payload 行）目录即域（T5.11）：   │
           │         │  顶层 = 系统域（default.nix = 系统海关，│
           │         │  有系统形态的平台才有）；home/ = 用户 │
           │         │  域（唯一保留字；home/default.nix =   │
           │         │  HM 海关，有独立门才有）·  文件存在性 │
           │         │  = 能力声明                           │
           │         └────────────────────┬──────────────────┘
           │                              │
┌──────────▼──────────────────────────────▼──────────────────┐
│  SHARED LAYER  ·  lib/shared/                              │
│  两阶段初始化：lang(前端) → runtime(IR 合成)               │
│  目标工厂 targets.nix：hosts/ 清单 → caps 分类 →           │
│  nixos / darwin / standalone-HM 三类 closure 发射器        │
│  （生产端：flake.nix 只写 inherit (targets) …；            │
│   策略 IR 每主机单实例化，T5.10）                          │
└──────────────────────────────┬─────────────────────────────┘
                               │
┌──────────────────────────────▼─────────────────────────────┐
│  SECRET LAYER  ·  secrets/ + .sops.yaml                    │
│  Age 加密 · SOPS 管理 · 最小权限 · 运行时注入              │
│  TMPL → KEY → RULE → PLAIN → CIPHER → /run/secrets/        │
└──────────────────────────────┬─────────────────────────────┘
                               │
┌──────────────────────────────▼─────────────────────────────┐
│  TEST LAYER  ·  tests/                                     │
│  6 平面 · 92 tests + pre-commit + docs-ssot = 94 checks    │
│         · nmt(零VM) + QEMU · CI 平面整面交接               │
└────────────────────────────────────────────────────────────┘
```

**数据流向（管道）：**

```
shared.nix (策略)
    ↓ just shared-generate
lib/shared (两阶段初始化：lang → runtime)
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

---

## 设计原则

| 原则         | 体现                                                                                                          |
| ------------ | ------------------------------------------------------------------------------------------------------------- |
| **依赖倒置** | `lib/shared` 定义抽象 schema/enum，上层模块依赖抽象接口而非具体实现；`shared` 作为 specialArgs 注入           |
| **管道流**   | `shared.nix → lib/shared → targets → flake → platform/home → modules` 单向数据流，无反向依赖；三段式镜像编译器管道：lang（frontend）→ runtime（IR 合成）→ targets.nix（codegen） |
| **层级化**   | entry / host-dispatch / system / user / shared / secret / test 七层，职责不交叉，层间通过 `shared` 通信       |
| **增量模式** | 每个子目录均为独立模块，可单独启用/禁用；`imports` 列表即模块注册表                                           |
| **策略管理** | `shared.nix` 集中声明 platform · drive · wm · dm · shell · editor 等所有策略选项，单一真相源                  |
| **分发层收敛** | 平台语义只回答一次：`enum.platform` 行携带 `caps` 能力向量与策略载荷（home-prefix · btop · trace-tools），targets 分类器、发射器与全部叶子读同一张表（`shared.caps.*` / `shared.platform.value.*`）；配置树中零 if-else、零原始 tag 比较（T4.0，借鉴编译器多层管道：后续 pass 查询目标描述，绝不重新词法分析） |
| **状态机**   | `lib/shared/lang/enum.nix` 通过 `nix-types` enum 约束合法状态集合，非法值在求值阶段即报错                    |
| **生命周期** | devShell 四阶段钩子：`preInputsHook → postInputsHook → preShellHook → postShellHook`                          |
| **边界明确** | system layer 不感知用户配置；user layer 不直接操作硬件；host layer 是唯一的平台感知点                         |
| **生成不变** | `shared.nix` 由模板生成（覆盖写入），不可 sed 原地 patch；`.sops.yaml` 同理                                   |
| **数据驱动** | `secrets.just` 零硬编码路径，所有 secret 路径运行时从 `shared.nix` 读取；CI checks 按平面整面交接（`api.checks.planes`，T7.3）    |
| **通信协议** | 层间通过 `shared` attrset 传递（`specialArgs`/`extraSpecialArgs`）；`api.inputs` / `api.shared` / `api.targets` / `api.checks.planes` 暴露 flake 侧信息供脚本与 CI 查询 |
| **数据与解释器分离** | 机器事实归 `hosts/`（facter.json 硬件数据 · disk.nix 磁盘布局 · persist.nix 状态策略），解释能力归平台结构树（nixpkgs facter 模块 · disko 注册 · impermanence + 回滚机制）；主机入口只做一行接线（T5.12/T5.13/T5.14） |

---

## 目录语法 — 平台分发层的文法

平台分发层（`platform/`）遵循**目录即域**文法（v3，T5.11）。读目录即知平台形态，读文件名即知域。

```
platform/<tag>/
├── default.nix        # 系统海关（系统域顶层）—— 有系统形态的平台才有
├── core/ dm/ wm/      # 系统树（nixos 的系统形态子系统，自由生长）
└── home/              # 用户域 —— 唯一保留的顶层名
    ├── default.nix    # HM 海关 —— 平台保有独立 standalone 门才有
    └── <arch>.nix     # HM payload 行（arch 轴的地址）
```

**文法六律：**

1. **顶层 = 系统域，`home/` = 用户域。** 文件存在性 = 能力声明（caps 表在文件系统上的投影）：`linux/`、`wsl/` 顶层没有 `default.nix`，因为它们没有系统形态；`darwin/` 的 `home/` 里没有 `default.nix`，因为它的 HM 不走独立门。
2. **每活门一海关。** `nixos` 双活门 → 两个海关文件（`default.nix` + `home/default.nix`）；`darwin` 单活门 → `default.nix` 一个文件（T5.8 单门折叠：系统路由 + arch 分发 + HM module mode 挂载一体，跨域引用在路径上可见）。
3. **target double。** platform 轴选目录（caps 分类决定哪个发射器到达），arch 轴选用户域内的 payload 行。arch 维仅存在于用户域——系统域的 arch 差异由发射器的 `system` 参数在 nixpkgs 层吸收。
4. **一个路径只有一个含义。** 顶层同名异义债务为零（v2 消灭了 default.nix 双关，v3 把 arch 轴写进目录位置）。
5. **海关只装配/路由，永不装内容。** payload 与系统树互不 import；`hosts/` 是唯一 per-host 差异点。
6. **声明而不存在的路径在 eval 期响亮失败。** 目录路由是字符串插值（`./${shared.arch.tag}.nix`），落到不存在的行即报错——declared-but-absent 从 arch 文件扩展到整个文法。

**五平台形态表：**

| platform | 系统形态 | 独立 HM 门 | 目录形态 |
| -------- | -------- | ---------- | -------- |
| `nixos` | ✅ `default.nix` + `core/ dm/ wm/` | ✅ `home/default.nix` + payload 行 | 双门双海关（策略：standalone HM 秒级切换、独立于系统世代回滚） |
| `darwin` | ✅ `default.nix`（单门折叠，HM 以 module mode 内乘） | ✗（payload 行仍驻 `home/`，由系统关挂载） | 单门单海关 |
| `linux` | ✗ | ✅ `home/default.nix` | 整个平台目录即用户域 |
| `wsl` | ✗（Windows 宿主持有内核侧） | ✅ `home/default.nix` | 整个平台目录即用户域 |
| `nixos-wsl` | ✅ 薄门：`default.nix` = `../nixos` 复用 + NixOS-WSL 解释器（T7.1） | ✅ `home/default.nix`（payload 行回用 nixos 用户域） | 双门；系统海关即整个形态定义：读门即知「nixos customs + WSL 解释器」 |

**子系统路由的两种形态（零 if-else）：**

```nix
# 单选（目录插值）：platform/nixos/dm/default.nix
imports = [ ./${shared.display-manager.tag} ];      # ly → ./ly

# 多选（map 路由）：platform/nixos/core/drive/default.nix
imports = builtins.map (drive: ./${drive}.nix) shared.drive.value;
# shared.drive.value = [ "intel" "nvidia" ] → imports [ ./intel.nix ./nvidia.nix ]
```

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
│       │   ├── enum.nix    # 枚举与平台能力表：arch / platform(caps) / wm / dm / shell /
│       │   │               #   drive-group / editor-set / terminal-set / browser-set / app-set /
│       │   │               #   service-profile / version / pointer-cursor
│       │   ├── schema.nix  # 结构验证：user / git / rbw / time / i18n / secrets / shared
│       │   ├── fn.nix      # 纯工具函数：homeDir · sopsBase/sopsFile/sopsRuntimePath ·
│       │   │               #   pkgsFingerprint · sameSource（eval 期双源守卫）
│       │   ├── const.nix   # 常量：secrets 路径 · 权限模式(0400/0440/0600) · XDG 目录名
│       │   ├── tools.nix   # 外部工具库注册：nix-types / orc-raw / pdshell-raw（短路径访问）
│       │   └── validate.nix# Option/Result 类型化 secret 路径校验（eval 期 declared-but-not-provided）
│       └── runtime/
│           └── default.nix # 阶段二 · IR 合成：caps/pkgs/upkgs/i18nScope/services/appCategories/…
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
│   ├── wsl/                # WSL2：home/default.nix = 唯一海关（standalone HM + nixGL +
│                           #   genericLinux + systemd；无系统形态，顶层无 default.nix；
│                           #   整个平台目录即用户域；WSL 用户空间 interop 由共享树
│                           #   home/core/base/wsl.nix 按 caps.wsl 提供，T7.1）
│   └── nixos-wsl/          # NixOS-WSL 第五形态（T7.1）：default.nix = 薄门——
│                           #   ../nixos 复用 + NixOS-WSL 解释器；home/ = 用户域
│                           #   （payload 行回用 nixos 用户域行；门即形态定义）
│
├── home/                   # 用户层（Home Manager）—— 无根入口，仅由 payload 行导入
│   ├── core/
│   │   ├── base/           # 基础：字体 · i18n(fcitx5) · portal(wm 策略驱动) · XDG
│   │                   #   · wsl（caps.wsl 门控的 WSL 用户空间 interop：wslview/WSLENV，T7.1）
│   │   ├── exp/            # 扩展功能（可选模块）
│   │   │   ├── app/        # GUI 应用（app-set 重量级路由，T5.10：
│   │   │   │               #   full=全树 / lean=文档·阅读·逆向 / none=仅三选集目录）：
│   │   │   │               #   16 类：browser · dl · editor · fm · game · im · image · misc
│   │   │   │               #   · model · music · note · office · re · reader · terminal · video
│   │   │   └── sys/        # 系统工具（常开层，不进 app-set 重量级轴）：
│   │   │       ├── ai/         #   AI CLI：claude-code · opencode · gemini-cli · kiro-cli
│   │   │       │               #   · cursor-cli · pi-coding-agent
│   │   │       ├── base/       #   基础 CLI：git · fzf · bat · eza · fd · ripgrep · yazi
│   │   │       │               #   atuin · starship · direnv · tmux · rbw · just · jq · yq
│   │   │       │               #   wl-clipboard · cliphist · wl-clip-persist · tealdeer · curl · wget
│   │   │       ├── compat/     #   兼容：appimage-run
│   │   │       ├── fs/         #   文件系统：compress(zip/p7zip/zstd) · duf
│   │   │       ├── media/      #   媒体：ffmpeg · mpv
│   │   │       ├── misc/       #   杂项：cava · cursor(指针主题)
│   │   │       ├── monitor/    #   监控：btop · htop · bottom
│   │   │       └── shell/      #   Shell：zsh(fzf-tab+atuin) · fish(fzf-fish+autopair)
│   │   ├── sec/            # 用户安全（扩展点，系统侧在 platform/nixos/core/sec）
│   │   └── srv/            # 用户服务：
│   │       ├── db/         #   数据库客户端工具
│   │       ├── notify/     #   通知：mako
│   │       └── security/   #   安全：gnupg keyring
│   ├── wm/
│   │   ├── hyprland/       # Wayland WM（主力）：hyprland + orc wallust 注入 + 完整主题栈
│   │   │   └── theme/      # quickshell · rofi · swaync · satty · swayosd · wallust · waybar · wlogout · qtct
│   │   ├── niri/           # Wayland WM（备选）：niri + 主题栈
│   │   │   └── theme/      # satty · swaylock · swaync · swayosd · waybar · wlogout
│   │   └── none/           # Null-Object：空模块（其存在让 payload 行的无条件 import 成立）
│   └── env/
│       ├── base/           # 全局基础包：clang · cmake · rustc · cargo · python314 · nodejs_26
│       │                   # 调试工具：valgrind · strace · ltrace · pciutils · vulkan-tools
│       └── dev/            # pdshell devShell 定义（每语言一目录，非 HM 模块树）
│           ├── asm · c · cpp · go · java · javascript · typescript
│           ├── lisp · lua · nix · python · re · rust · zig
│           └── default.nix # 复合环境：default(全语言) · cpython · godot · makeOs · rs_compiler_dev
│
├── hosts/                 # 多主机支持（per-machine facts + policy overrides）
│   ├── nixos/             # 默认主机：hardware.nix（legacy 生成）+ default.nix（NVIDIA 指纹）
│   ├── vm/                # 评估级 VM 主机：facter.json + disk.nix + persist.nix（声明式
│   │                      #   硬件/磁盘/状态事实，T5.12/T5.13/T5.14）
│   │                      #   + shared.nix 策略覆盖（ephemeral root：/ 每次启动回滚清空，
│   │                      #   /persistent · /nix · /boot 为同级 subvol 存续）
│   ├── wsl/               # WSL 主机：shared.nix（platform=wsl 类翻转，无系统事实文件）
│   ├── nixos-wsl/          # NixOS-WSL 主机（T7.1）：shared.nix（platform=nixos-wsl
│                           #   第五行翻转 + dm/wm none + lean 集）+ default.nix（唯一机器
│                           #   事实 = arch——无 facter/disk/persist，见文件头）
│   └── darwin/            # darwin 主机：shared.nix（platform=darwin + aarch64-darwin）
│                          #   + default.nix（eval 级主机入口，activation 待真机）
│
├── secrets/
│   ├── chipr/              # SOPS 加密文件（提交到 Git；.sops.yaml 管控解密权限）
│   └── plan/               # 明文模板实例（⚠️ 禁止提交 Git，.gitignore 已排除）
│
├── export/
│   ├── nixos/              # 可复用 NixOS 模块（flake 输出 nixosModules：portal · fcitx5）
│   └── home/               # 可复用 Home Manager 模块（homeModules：fcitx5 · shell · waybar · yazi）
│
├── overlays/               # nixpkgs overlay：additions(pkgs/) · patches
├── pkgs/                   # 自定义 derivation（wslview —— wslu 归档后的最小 shim）
│
├── tests/                  # 测试层（6 平面，92 tests + 2 仓库卫生 checks = 94 checks）
│   ├── default.nix         # 统一注册表：Plane 0–5 全部 checks（nixosTest runner）
│   ├── test_calc.nix       # Plane 0: Smoke 基线
│   ├── nixos/              # Plane 1: NixOS-Plane（QEMU VM，29 tests）
│   ├── home/               # Plane 2: HM-Plane（QEMU VM + packages，41 tests）
│   ├── lib/                # Plane 3: Lib-Plane（纯 Nix eval，QEMU 256 MB minimal，5 tests）
│   ├── integration/        # Plane 4: Integration-Plane（NixOS + HM 联合，1 test）
│   ├── fixtures/           # eval 期 secret 存在性 fixture（pathExists 探针）
│   └── nmt/                # Plane 5: nmt-Plane（零 VM，纯 eval，15 tests）
│       ├── default.nix     # buildHomeManagerTest 实现 + 注册表（含包擦洗白名单）
│       └── home/           # 测试文件（lib.nmt.buildHomeManagerTest）
│
├── scripts/
│   ├── just/               # justfile 子模块（单一职责分层）
│   │   ├── shared.just     # shared.nix 生成（tmpl → generate → overwrite）
│   │   ├── hardware.just   # 硬件事实生成（facter 声明式 / generate legacy）
│   │   ├── disk.just       # disko 磁盘布局 + 状态策略（disk-show/persist-show 求值验收 / disk-format 应用）
│   │   ├── flake.just      # flake inputs 依赖管理 + deploy 组（nixos/home-switch）
│   │   ├── devenv.just     # 开发环境 profile 管理（pdshell，username 从 shared.nix 读取）
│   │   ├── services.just   # 按需服务管理（systemctl 动词封装）
│   │   ├── secrets.just    # Age 密钥 + SOPS 加密生命周期（双域密钥层级 + 注册表驱动）
│   │   ├── commit.just     # 数据驱动的提交规范部署（基于 commit-config flake input）
│   │   └── dump.just       # 项目文本导出（文档/审计用）
│   └── sh/                 # shell 工具（path_headers @path 头部守卫 · test-count 计数
│                           #   单一来源 · secrets-rotate 轮换 runbook · dump 管道）
│
├── docs/
│   ├── preview/            # 截图预览
│   ├── modules/            # export/ 模块接口规范（interface-standards.md）
│   ├── secrets/            # 密钥层级与轮换 runbook（rotation.md）
│   ├── tests/              # 测试文档：test-matrix.md · nixosTest.md · nmt.md
│   └── tmpl/
│       ├── shared.nix.tmpl # 策略层模板（__USERNAME__ 占位符；提交到 Git）
│       └── sops/           # SOPS secret YAML 模板（镜像路径层级结构）
│           ├── sops-rules.yaml.tmpl
│           └── nixos/      # 模板 YAML 文件（__USERNAME__ / __SECRET_VALUE__ 占位符）
│
├── .github/
│   └── workflows/
│       ├── ci.yml          # 8 阶段 CI 流水线（lint → deep-eval → nmt → devshells
│       │                   #   → security → vm-tests → host-toplevels → summary）
│       └── update-flake.yml# 每周日自动更新 flake inputs 并开 PR
│
└── justfile                # 任务自动化入口（ROOT 变量 + import 子模块 + 裸 just 地图）
```

---

## 核心机制

### 1. 共享层 — 两阶段初始化

`lib/shared` 解决了 Nix 中"配置依赖 pkgs，pkgs 依赖配置"的循环问题：

```
阶段一 (lang/):  const(常量) + schema(结构定义) + enum(合法状态与能力表) + fn(纯函数)
                 + tools(外部工具库注册) + validate(Option/Result 铁路)
                 ↓ 纯 Nix 表达式，不依赖 pkgs，可在求值阶段完整验证
阶段二 (runtime/): base_shared ⊕ hosts/<h>/shared.nix (浅 // 合并 + schema 再验证
                 + hostName 对齐) → 合成完整 IR
                 ↓ 注入: caps · pkgs/upkgs · i18nScope · homeDir · orc · pdshell
                 · sopsFile/sopsPath/sopsUserPath · editors/terminals/browsers
                 · appCategories · services · shellIntegrations · provenance
fullShared = lang(阶段一) ∪ user_shared ∪ runtime(阶段二注入)
```

**合并顺序（后者覆盖前者）：**

```nix
# lib/shared/runtime/default.nix
core_shared = shared // user_shared // {
  inherit
    homeDir
    pkgs upkgs orc pdshell
    caps i18nScope
    sopsFile sopsPath sopsUserPath
  ;
  _user_shared = user_shared; # 原始快照，调试使用
  inherit (pdshell) mk-pdshell pdshells;
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

| 字段              | 来源         | 说明                                                             |
| ----------------- | ------------ | ---------------------------------------------------------------- |
| `caps`            | runtime 解析 | 平台能力向量（`caps.nixos-system` 等）——**平台语义唯一的解析点** |
| `pkgs`            | runtime 注入 | 稳定版 nixpkgs（含 overlays + config）                           |
| `upkgs`           | runtime 注入 | unstable nixpkgs（第二个 nixpkgs 实例，非 overlay）              |
| `i18nScope`       | runtime 解析 | i18n 输入法包的作用域（stable/unstable 表驱动，双源混装在此响亮失败） |
| `homeDir`         | runtime 计算 | 平台感知的 home 目录（Linux: `/home/<u>`，macOS: `/Users/<u>`）  |
| `orc`             | runtime 注入 | configuration-orchestrator lib（arch 解析，wallust 主题注入）     |
| `pdshell`         | runtime 注入 | pdshell 管道流开发环境构建工具                                   |
| `pdshells` / `mk-pdshell` | runtime 注入 | pdshell 函数别名                                                |
| `editors` / `terminals` / `browsers` | set-enum 展平 | editor-set/terminal-set/browser-set 的选中叶列表（叶子路由用） |
| `appCategories`   | set-enum 展平 | app-set 的目录列表（`home/core/exp/app` 的 map 路由键）          |
| `services`        | set-enum 展平 | service-profile 的 `{db,virt}.{install,autostart}` 矩阵         |
| `shellIntegrations` | enum 载荷  | shell 的集成真值表（8 个 base 模块复用）                         |
| `sopsFile`        | runtime 注入 | `rel → store path`，从 secret REL 推导加密文件路径               |
| `sopsPath`        | runtime 注入 | `rel → /run/secrets/<rel>`，普通 secret 运行时路径               |
| `sopsUserPath`    | runtime 注入 | `rel → /run/secrets-for-users/<rel>`，neededForUsers secret 路径 |
| `provenance`      | runtime 计算 | 双通道 nixpkgs 指纹（`pkgsFingerprint`，eval 期日志与审计）      |
| `_user_shared`    | runtime 保留 | 原始 user_shared 快照（调试/内省用）                             |
| `packages`        | runtime 注入 | `pkgs` 目录导入的自定义 derivation 集合                          |
| `overlays`        | runtime 注入 | `overlays` 目录导入的 overlays（含 patches）                      |

**工具函数（`shared.fn`，全为纯函数）：**

```nix
shared.fn.homeDir  shared.platform shared.user.username   # → "/home/kilig" 或 "/Users/kilig"
shared.fn.sopsBase shared.self shared.const.secrets.chipr # → chipr 目录的 store 路径
shared.fn.sopsFile shared.self shared.const.secrets.chipr "nixos/core/base/user/kilig/password"
shared.fn.sopsRuntimePath shared.const.secrets.forUsersPath "nixos/core/base/user/kilig/password"
shared.fn.pkgsFingerprint pkgs                            # → nixpkgs 版本指纹
shared.fn.sameSource pkgA pkgB shared.i18n.nixpkgs-source # → eval 期双源守卫（995d8c9 事故的
                                                          #    结构性免疫：stable/unstable 混装在此 throw）
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

**工具库统一管理（`shared.tools`）**——外部工具库集中注册，配置文件通过短路径访问，解耦对 `inputs.<long-name>.lib` 的直接引用：

```
lib/shared/lang/tools.nix
    ├─ nix-types（短别名 nt）    — ADT 系统：enum / match / Option / Result
    ├─ orc-raw                  — configuration-orchestrator（arch-specific，runtime 解析）
    └─ pdshell-raw              — pipeline-driven dev shell manager

配置文件消费方式：
    shared.tools.nix-types.match shared.version { ... }     # 替代 inputs.nix-types.lib.match
    shared.orc.mergeHomeFiles ...                           # runtime 已按 arch 解析
```

随后 `shared` 作为 `specialArgs`/`extraSpecialArgs` 传递给所有 NixOS/Home Manager 模块，模块通过 `{ shared, ... }` 消费。

**`api.*` — 脚本可查询的 flake 侧索引：**

```nix
# flake.nix
api.inputs  = inputs;            # 全部 flake inputs（just 脚本动态枚举，零硬编码）
api.shared  = targets.base;      # 基策略 IR 句柄（与分发层共读一个实例，T5.10）
api.targets = targets.inventory; # { hostNames nixosHosts darwinHosts standaloneHosts }
api.checks.planes = ...;         # 测试矩阵的平面分组（T7.3）——CI 整面交接 nix-fast-build
api.host-toplevels = ...;        # Linux 主机系统闭包（T8.2）——inventory 驱动，
                                 #   CI 闭包级构建整面交接（darwin 跨系统仅求值）

# 示例：
nix eval .#api.inputs --json | jq -r 'keys'
# → ["commit-config", "cnmplayer", "home-manager", "hyprland", ...]

nix eval .#api.targets --json
# → 主机清单 + 三类分类结果（CI/脚本巡检用）

# flake-update-not-sops 利用此接口排除 sops-nix：
nix eval .#api.inputs --json | jq -r 'keys - ["sops-nix"] | join(" ")'

# CI 构建阶段按平面整面交接（成员 = 同一求值的 thunk，零额外成本）：
nix eval .#api.checks.planes --apply 'p: builtins.mapAttrs (_: builtins.length) p'
# → { "home": 41, "integration": 1, "lib": 5, "nixos": 29, "nmt": 15, "smoke": 1 }
```

### 2. 策略层 — shared.nix 生成机制

`shared.nix` 是整个系统的单一真相源，所有平台相关决策集中于此。

**生成不变（Generate, Don't Mutate）**

```
docs/tmpl/shared.nix.tmpl   手动维护，含 __USERNAME__ 占位符（提交 Git）
    ↓  just shared-generate <username>   (sed 替换 → 覆盖写入)
shared.nix                  生成产物，覆盖写入，不可 sed patch（提交 Git）
    ↓  lib/shared/default.nix: 两阶段初始化 + hosts/<h>/shared.nix 浅 // 合并
fullShared                  运行时合成（lang + user_shared + runtime）
    ↓  specialArgs / extraSpecialArgs
platform/ · home/           通过 { shared, ... } 消费
```

**主机策略覆盖（wholesale 语义）：** `hosts/<h>/shared.nix` 是对基记录的**浅整体替换**——顶层键整个换掉，永不深合并（enum 实例是 attrset，深合并会腐蚀策略载荷）；合并后过 schema 再验证，`hostName` 由加载器强制对齐到目录名（在 hosts/foo 里加载却路由到 bar 是不可能的）。基主机（nixos）无覆盖文件——基记录本身就是它的策略。

**可配置枚举（lib/shared/lang/enum.nix）：**

| 字段              | 合法值                                                                                                                                                                                                                                                                                                                                        |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `arch`            | `x86_64-linux` · `aarch64-linux` · `x86_64-darwin` · `aarch64-darwin` · `i686-linux`                                                                                                                                                                                                                                                          |
| `platform`        | `nixos` · `linux` · `darwin` · `wsl` · `nixos-wsl`（每行携带 `caps` 能力向量与策略载荷）                                                                                                                                                                                                                                                                     |
| `window-manager`  | `hyprland` · `niri` · `gnome` · `none`（Null-Object；每个值携带 `portal` 策略）                                                                                                                                                                                                                                                               |
| `display-manager` | `ly` · `gdm` · `sddm` · `lemurs` · `none`（T7.1 Null-Object 行——控制台形态）                                                                                                                                                                                                                                                                  |
| `drive-group`     | `intel` · `amd` · `nvidia` · `nvidia-prime` · `amd-nvidia` · `amd-nvidia-prime` · `intel-nvidia` · `intel-nvidia-prime`                                                                                                                                                                                                                       |
| `shell`           | `zsh` · `fish` · `bash`（每行携带 `integrations` 集成真值表）                                                                                                                                                                                                                                                                                 |
| `editor`          | `nvim` · `vim` · `code` · `zeditor`                                                                                                                                                                                                                                                                                                           |
| `editor-set`      | `minimal` · `full-ai` · `dev` · `full`（多选路由，携带 `editors` 列表）                                                                                                                                                                                                                                                                  |
| `terminal-set`    | `kitty-only` · `wezterm-only` · `both`（多选路由，携带 `terminals` 列表）                                                                                                                                                                                                                                                                      |
| `browser-set`     | `chrome-only` · `qutebrowser` · `cli-only` · `chrome-qute` · `all`（多选路由，携带 `browsers` 列表）                                                                                                                                                                                                                                           |
| `app-set`         | `full` · `lean` · `none`（目录级路由，T5.10 惰性模块加载：携带 `categories` 列表——主机合并哪些 app 树；browser/editor/terminal 三目录随每行必达（自身由各自 set 剪枝）；`full` 行顺序即模块合并序，闭包哈希指纹锚点，由 enum 测试锁定）                                                                                     |
| `service-profile` | `full-autostart` · `dev-on-demand` · `server-pg-only` · `minimal`（策略携带，控制 db/virt 的 install vs autostart）                                                                                                                                                                                                                             |
| `pointer-cursor`  | `Bibata-Modern-Amber` 等 12 个 Bibata 变体                                                                                                                                                                                                                                                                                                    |
| `version`         | `v25_11`（携带 `{stateVersion, wine, swww, adb}` 策略） · `v26_05`（同构）                                                                                                                                                                                                                                                                          |

`window-manager` 枚举值内嵌 `portal` 策略，`platform/nixos/core/base/portal.nix` 和 `home/core/base/portal.nix` 直接消费：

```nix
# enum.nix 中的结构
hyprland = { portal = { default = [ "hyprland" "gtk" ]; extraPortals = (pkgs: ...); wlr = false; }; };
niri     = { portal = { default = [ "wlr" "gtk" ];      extraPortals = (pkgs: ...); wlr = true;  }; };
gnome    = { portal = { default = [ "gtk" ];            extraPortals = (pkgs: ...); wlr = false; }; };

# 消费侧（portal.nix）
xdg.portal.extraPortals = shared.window-manager.portal.extraPortals pkgs;
xdg.portal.config.common.default = shared.window-manager.portal.default;
```

**平台能力表（T4.0 分发层收敛）—— `enum.platform` 即目标描述：**

```nix
# lib/shared/lang/enum.nix：每行回答"该平台是什么"，一处声明
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

### 3. 分发层 — targets.nix 目标工厂

`lib/shared/targets.nix` 是目标构造的生产端——编译器形状的后端 pass。三段流水：

```
前端     hostNames = readDir ../../hosts（仅目录）
             ↓ 加机器 = mkdir hosts/<name>，零 flake.nix 改动
中间端   caps 分类（查能力表，永不重词法分析目标）：
             nixosHosts      = caps.nixos-system
             darwinHosts     = caps.darwin
             standaloneHosts = !caps.darwin（darwin standalone 会携带 linux pkgs——结构性排除）
后端     三类发射器（统一目录引用，语法 v3）：
             mkNixosSystem  → modules = [ ../../platform/${tag} ]        （hostPlatform 来自主机事实）
             mkDarwinSystem → modules = [ ../../platform/${tag} ]        （system = arch.tag 参数吸收）
             mkHomeSystem   → modules = [ ../../platform/${tag}/home ]   （standalone HM 门）
```

**策略 IR 单实例化（T5.10，分发层 CSE）：** `sharedByHost = genAttrs hostNames mkShared` 单表，分类器/发射器/命名/别名全部读表；默认主机表项 = 基实例（句柄共享，默认主机永不为同一份 IR 付两次钱）；flake.nix 的基 `shared` 消费 `targets.base`（后端导出已建好的基 IR 句柄）而非二度 import。遗留别名 `<user>-<platform>` 是 attr 级 thunk 别名（共享同一闭包，非重发射）。

**产出成品（flake.nix 只写 inherit）：**

```nix
inherit (targets) nixosConfigurations;   # 每台 nixos 主机 + legacy 别名
inherit (targets) homeConfigurations;    # "<user>@<host>"（kilig@nixos · kilig@vm · kilig@wsl）
inherit (targets) darwinConfigurations;  # 每台 darwin 主机（darwin）
```

### 4. 开发环境管道 — pdshell

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
# home/env/dev/python/machine.nix — ML/DL 环境组合 C + Python
default = {
  shell = "zsh";
  combinFrom = [ dev.c dev.python ];   # 合并两个环境的所有 inputs 和 hooks
  postInputsHook = ''
    export LD_LIBRARY_PATH="${pkgs.gcc.cc.lib}/lib:$LD_LIBRARY_PATH"
    export UV_CACHE_DIR="$PWD/.cache/uv"
  '';
};
```

**可用 devShells 速查（25 个，`nix eval .#devShells.x86_64-linux --apply builtins.attrNames`）：**

| Shell 名称                     | 组合内容                              | 特性                          |
| ------------------------------ | ------------------------------------- | ----------------------------- |
| `rust`                         | rustc + cargo + rust-analyzer         | clippy · rustfmt              |
| `go`                           | go + gopls + delve                    | 中国镜像 · 项目级缓存         |
| `python`                       | python314 + uv + pyright              | ruff · bytecode 缓存隔离      |
| `python-machine`               | C + Python + gcc.cc.lib               | ML/DL 工具链 · GPU 指引       |
| `python-renpy`                 | python314 + renpy + unrpyc            | Visual Novel 开发             |
| `cpp`                          | pure LLVM (libc++ + clangd)           | lld · lldb · bear · ccache    |
| `c`                            | clang + clangd + lld                  | bear · ccache · cmake · ninja |
| `asm`                          | nasm + binutils                      | 汇编                          |
| `java`                         | temurin-21 + maven + jdt-ls           | gradle                        |
| `typescript`                   | node26 + tsc + tsx                    | typescript-language-server    |
| `javascript`                   | node26 + biome                        | pnpm · yarn                   |
| `nix`                          | nix + nil + statix + nixfmt           | deadnix · nvd                 |
| `nix-derivation-free`          | + nix-output-monitor + nixpkgs-review | PR 审查工作流                 |
| `nix-derivation-unfree`        | + patchelf + sbomnix + gpg            | 闭源软件构建 · 合规           |
| `nix-derivation-free-security` | + vulnix                              | 安全扫描                      |
| `nix-nonfmt`                   | 无 formatter 干扰的裸 nix shell        | 脚本编写                      |
| `re`                           | LLVM + 完整逆向工具链                 | pwntools · frida · ghidra     |
| `lua`                          | lua54 + luajit + lua-language-server  | stylua · luarocks             |
| `lisp`                         | sbcl + rlwrap                         | pkg-config · gcc              |
| `zig`                          | zig + zls                             |                               |
| `default`                      | 全语言 combinFrom 合并                | 综合开发环境                  |
| `cpython`                      | C + C++ + Python 组合                 |                               |
| `godot`                        | C + C++ + Python + godot              | 游戏开发                      |
| `makeOs`                       | asm + c + qemu_full + just            | OS 实验环境                   |
| `rs_compiler_dev`              | rust + 编译原理工具链                  | rs 开发                       |

### 5. 安全层 — SOPS + Age（分层管理）

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

**关于仓库状态与出厂态：** 本仓库携带维护者自己的 `.sops.yaml`（公钥）与
`secrets/chipr/**`（维护者 key 加密的密文）——它们对你**不可解**，也无须删除。
fork/采纳者的引导体验等同于出厂态：`just shared-generate <你的用户名>` 重新生成
策略后，`secrets-destroy-all`（清空维护者密文）→ `secrets-init` → `secret-set-all`
（你的 key 加密后提交）即完成接管。eval 期对无 blob 状态宽容
（`lib/shared/lang/validate.nix` 的 resolution pass 只 trace 引导命令）；
树上出现 blob 后即转严——声明而缺失的 secret 在 eval 期报
「declared but not provided」。deploy 在无密钥状态会在 sops 激活期硬失败
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
| `redis.user.password`          | `0440` | root     | redis-\<u\> | `/run/secrets`          |

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

### 6. 配置编排器 — orc（ConfigurationOrchestrator）

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

### 7. 用户环境层 — home/env

`home/env` 是独立于 `home/core` 的全局运行时环境层，在所有平台的用户域 payload 行（`platform/*/home/<arch>.nix`）中与 `home/core` 并列导入：

```
platform/<platform>/home/<arch>.nix
    imports = [ ../../../home/core  ../../../home/env  ../../../home/wm ]
```

**子层职责：**

| 子层       | 路径             | 说明                                                                                                                                  |
| ---------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `env/base` | `home/env/base/` | 全局基础包：编译器(clang/rustc/cargo)、运行时(python314/nodejs_26)、调试工具(valgrind/strace/ltrace)、硬件工具(pciutils/vulkan-tools) |
| `env/dev`  | `home/env/dev/`  | pdshell devShell 定义文件（每语言一目录，由 `flake.nix` 的 `devShells` 输出加载；**不是 HM 模块树**）                                  |

**`sys/ai/` — AI CLI 子层：**

`home/core/exp/sys/ai/` 是独立于 `sys/base/` 的 AI 工具子层，仅在 `home/core/exp/sys/` 中导入，包含：

| 工具          | 包名          | 说明                         |
| ------------- | ------------- | ---------------------------- |
| `claude-code` | `claude-code` | Anthropic Claude CLI（代码） |
| `opencode`    | `opencode`    | 开源 AI 编码助手             |
| `gemini-cli`  | `gemini-cli`  | Google Gemini CLI            |
| `kiro-cli`    | `kiro-cli`    | AWS Kiro CLI                 |
| `cursor-cli`  | `cursor-cli`  | Cursor AI 编辑器 CLI         |
| `pi-coding-agent` | `pi-coding-agent` | pi coding agent       |

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

### 8. 外部配置仓库（flake=false inputs）

所有工具配置以独立 Git 仓库形式引入（24 个 `flake = false` 输入，其中 22 个为 dotfile 配置仓库），由 Home Manager 在激活时写入 `~/.config/<app>/`：

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
| `btop-config`          | `~/.config/btop/`                                                           |
| `cava-config`          | `~/.config/cava/`                                                           |
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

（另两个 `flake = false` 输入非配置仓库：`nmt` 是测试框架 mirror，见[测试体系](#测试体系)。）

**CI 覆盖与职责边界**：这些仓库以 flake.lock 锁定 revision 被消费，本仓 CI
对它们的集成正确性已全覆盖——deep-eval 硬门禁求值 94 checks 强制 fetch 全部
输入（仓库消失/移动即失败）、nmt 平面物料化 home 激活（配置树实际写入）、
VM 平面真实启动含这些配置的系统；外部仓库的坏提交在 update-flake.yml 开出
的 PR 上即被拦截。各仓库自身的语言级 lint（stylua 等）归各仓库自己的 CI——
本仓是消费者而非所有者（裁决记录见[路线图](#路线图)末节）。

### 9. 提交规范 — Husky + Commitlint + Commitizen（零 node_modules）

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

### 10. 多主机支持 — hosts/

`hosts/` 目录实现多主机分发，每台机器独立硬件事实 + 可选 `shared.nix` 覆盖。当前承载 **5 台主机**（nixos · vm · darwin · wsl · nixos-wsl）。

**机器事实的三个文件（T5.12 + T5.13 + T5.14 — 数据 + 解释器路线）：**

```
hosts/
├── nixos/                   # 默认主机（legacy 形态）
│   ├── default.nix          # 主机入口（imports hardware.nix + NVIDIA prime 指纹下沉）
│   └── hardware.nix         # nixos-generate-config 自动生成（模块形态的机器事实）
├── vm/                      # 评估级第二主机（声明式形态 + ephemeral root 实验，T5.14）
│   ├── default.nix          # 主机入口（reportPath 一行 + imports ./disk.nix + ./persist.nix）
│   ├── shared.nix           # 策略覆盖（drive=amd · server-pg-only · app-set=none …）
│   ├── facter.json          # nixos-facter 报告（硬件事实的数据形态，T5.12）
│   ├── disk.nix             # disko 磁盘布局（磁盘事实的数据形态，T5.13；btrfs 四 subvol，T5.14）
│   └── persist.nix          # 状态策略（ephemeral-root 声明 + 生存清单，T5.14）
├── wsl/                     # WSL 主机（shared.nix 唯一——standalone HM 无系统事实文件）
├── nixos-wsl/               # NixOS-WSL 主机（T7.1：第五行翻转 + dm/wm none + lean 集；
│                            #   default.nix 的唯一机器事实 = arch——无 facter/disk/persist，
│                            #   三重缺省即三重声明：硬件/磁盘/状态各有其主）
└── darwin/                  # darwin 主机（shared.nix + default.nix eval 级入口）
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
数据归 hosts/**（与 sops-nix 注册于 core/sec/secret 同一裁决）；**persist.nix 是状态策略
数据**（「根是 ephemeral 的」这一机器事实 + 什么生存的清单 environment.persistence），由
impermanence 模块 + 回滚机制解释（同样不在 nixpkgs——已对锁定树核实，注册 =
`platform/nixos/core/base/impermanence.nix`）。三个事实对共享同一裁决链。数据与解释器分离的
价值与 hosts/ 本身同构：机器事实是前端数据，解释它的能力是后端，主机入口只做一行
接线。

真实机器迁移（在目标机上执行；磁盘布局是重装时机——disko 应用即重分区，数据不可保留）：

```
  1. just hardware-facter    # 生成 hosts/<hostname>/facter.json（root 扫描）
  2. 主机入口：imports = [ ./hardware.nix ] → hardware.facter.reportPath = ./facter.json;
  3. 删除 hardware.nix 中的 initrd/hostPlatform 行；fileSystems 走第 4 步
  4. 写 hosts/<hostname>/disk.nix（声明目标分区表）+ 主机入口 imports ./disk.nix；
     重装时从 installer 运行 just disk-format <hostname>（分区/格式化/挂载，破坏性）
  5. 可选（实验路线）：btrfs 布局 + hosts/<hostname>/persist.nix 声明 ephemeral root
     （enable + 生存清单）+ imports ./persist.nix——参考 hosts/vm 三件套
```

vm 的报告是**声明**而非探测产物——VM 的硬件本就是被定义的（QEMU x86_64 guest +
virtio 盘/网卡），报告按标准 schema 写出该形态（kvm 虚拟化、virtio_blk/virtio_net 的
driver_modules、无 vmx/svm 的 vCPU）。报告刻意不列 network_interface：平台的
NetworkManager 策略拥有 DHCP，facter 的 per-interface useDHCP 默认面向 scripted
networking，在 NM 之下会再挂一层 dhcpcd；CONTROLLER（virtio-net）在报告中，
驱动照样进 initrd。同理，vm 的磁盘布局也是声明：GPT + EF02（BIOS boot，grub core.img
的 1MiB staging）+ root btrfs 占满余盘，四个 subvol 四种寿命（T5.14）：`root` 挂在 /
（ephemeral——每次启动被回滚机制归档到 old_roots/<timestamp> 并重建为空）、
`persistent` 挂在 /persistent（状态）、`nix` 挂在 /nix（store 闭包存续）、`boot` 挂在
/boot（引导链——内核与 grub.cfg 绝不能随根蒸发）。布局中的 EF02 分区就是 disko 派生
`boot.loader.grub.devices = ["/dev/vda"]` 的依据（BIOS 形态的结构化表达），与 facter
报告的 `uefi: false` 互相印证；主机文件里只补齐引导策略对齐（grub on /
systemd-boot off——平台默认面向 UEFI 机器群）。

**ephemeral root（T5.14 实验，仅 vm）：** `just persist-show vm` 可读出整张状态契约。
回滚机制是平台侧解释器（`platform/nixos/core/base/impermanence.nix`）：读布局已声明的
根挂载事实（device/fsType/subvol——disko _config 输出），派生上游权威配方（impermanence
README.org 的 BTRFS subvolumes 节）：归档旧根 → 删除超过 retain-days（默认 30 天）的旧根
→ 重建空 subvol → 才挂载 /。**两种 initrd 模式、同一配方**：systemd stage 1（平台 fleet
默认）落地为 sysroot.mount 之前的 oneshot（门在根设备 unit 上——systemd-repart 先例）；
classic stage 1 落地为 postResumeCommands（根挂载循环之前执行——上游钩子）。btrfs-progs
进 initrd 不是手接线：nixos 的 btrfs task 模块从 fileSystems fsType 自动推导。上游已断言
「每个 persistence 路径必须 neededForBoot」，解释器用 mkDefault 满足之；本仓更严一条：
每个 persistence 路径必须是已声明的 mount（布局缺口→求值期大声失败）。

platform/nixos/default.nix 通过 ../../hosts/${shared.hostName} 动态路由到对应主机（系统海关
挂载 host facts；darwin 的海关同理）。**消费不对称**：`hosts/<h>/default.nix` 只被
系统海关导入；`hosts/<h>/shared.nix` 被每一类 closure 的策略加载器消费——standalone
HM 路径永不触碰主机系统事实。
新增主机只需：

```
  1. mkdir hosts/<new-hostname>
  2. just hardware-facter    # 写入 hosts/<hostname>/facter.json（或 hardware-generate 走 legacy）
  3. 写 hosts/<new-hostname>/shared.nix（策略覆盖；基主机无此文件）
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

# 配置文件消费（platform/nixos/core/srv/db/postgresql.nix）
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
2. **深层求值** — `nix flake check --no-build` 对全部 94 checks 做完整 eval（含 8 闭包）
3. **Secret 完整性** — 验证加密文件结构正确，`secrets/plan/` 未被提交
4. **测试覆盖** — 92 tests 覆盖 nixos/home/lib/integration/nmt 平面
5. **自动更新** — 每周日自动更新 flake inputs 并开 PR

### 实际 Pipeline（8 阶段，最大并行）

```
push / PR
    │
    ├─► [STAGE 1: Lint & Evaluate]     静态分析 + 浅层 eval（< 2 min）
    │       ├── nix eval .#formatter.*.name          (formatter 可求值)
    │       ├── nix eval .#devShells.* attrNames     (devShells 非空)
    │       ├── nix eval .#nixosConfigurations attrNames  (结构验证)
    │       ├── nix eval .#homeConfigurations attrNames
    │       ├── nix eval .#checks.* attrNames + 平面计数
    │       ├── statix check .                       (Nix 反模式检查)
    │       ├── nixfmt check / deadnix check
    │       ├── Build pre-commit-check derivation
    │       └── Build docs-ssot-check derivation     (T8.1：文档计数锚点)
    │
    ├─► [STAGE 2: Deep Evaluation]     深层求值（硬门禁）
    │       └── nix flake check --no-build            (94 checks 全量 eval；
    │           含 6 closure 求值——validate.nix 对无 blob 状态宽容，
    │           出现 blob 后转严 declared-but-not-provided)
    │
    ├─► [STAGE 3: nmt-Plane]           HM dotfile 断言，纯 eval，无 KVM（< 1 min）
    │       └── nix-fast-build --flake .#api.checks.planes.nmt（并行求值+构建，T7.3）
    │
    ├─► [STAGE 4: devShells dry-run]   devShell 矩阵（并行）
    │       └── rust · python · python-machine · nix · go · cpp · c · typescript · re …
    │
    ├─► [STAGE 5: Security Audit]      SOPS 完整性审计（并行）
    │       ├── secrets/chipr/*.yaml 必须含 sops: 元数据
    │       ├── secrets/plan/ 不得被 git 追踪
    │       ├── .sops.yaml 含 age: + creation_rules:
    │       └── .nix 文件扫描硬编码 token/password
    │
    └─► [STAGE 6: VM Tests]            QEMU 测试，按平面并行子矩阵（需 KVM）
            ├── 每腿一平面，整面交 nix-fast-build（nix-eval-jobs 并行求值
            │   + 流水线构建，--skip-cached 对接 magic-nix-cache，T7.3）：
            ├── smoke        — 基线（1）
            ├── nixos        — 系统模块（29）
            ├── home         — HM 模块（41）
            ├── lib          — lib 纯表达式（5）
            └── integration  — NixOS + HM 联合激活（1）

    └─► [STAGE 6.5: Host Toplevels]   系统闭包构建（T8.2，无 KVM）
            ├── .#api.host-toplevels 整面交 nix-fast-build（inventory 驱动：
            │   nixos · vm · nixos-wsl——新 NixOS 主机按构造入列；
            │   cache.nixos.org 替代 + magic-nix-cache 跨次缓存）
            └── darwin 闭包跨系统仅求值（aarch64-darwin——构建需
                darwin runner/交叉工具链，环境门控）

    └─► [STAGE 7: Summary]             汇总报告（always，即使前序失败）
```

> **deep-eval 硬门禁**：早期 CI 不跑 `nix flake check`（sopsFile store 路径在
> `--no-build` 下不物化）。该阻塞已被 `lib/shared/lang/validate.nix` 的
> Result 铁路消除——eval 期对 secret 的检查改为「声明而缺失才报错」，与 store
> 物化无关。深层求值现在是硬门禁（T5.13 曾靠它捕获过 T5.2 改名残留导致的
> 四处坏测试引用）。

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
    │       └── 7 stage passes             │
    │                                      │
    └── [CI Pass]                          │
        │   cd /etc/nix-config             │
        │   git pull                       │
        │                                  │
        │   just nixos-switch nixos        # = sudo nixos-rebuild switch --flake .#nixos
        │                                  │
        │   just home-switch nixos         # → home-manager switch --flake .#kilig@nixos
        │                                  │
        └── systemctl status sops-*
            just secret-get mongodb
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

测试套件覆盖 6 个平面，总计 **94 checks = 92 tests + 1 pre-commit-check + 1 docs-ssot-check**（计数由 `tests/docs-ssot.nix` 机器强制——README 与 test-matrix 的计数锚点漂移即 CI 红灯，T8.1；本地速查仍可用 `scripts/sh/test-count.sh`，其输出与 CI summary 对账）：

| 平面        | 前缀           | 数量   | KVM            | 关注点                         | 典型时长 |
| ----------- | -------------- | ------ | -------------- | ------------------------------ | -------- |
| Smoke       | `test_`        | 1      | QEMU           | 基本系统完整性                 | ~1 min   |
| NixOS       | `nixos_`       | 29     | QEMU           | platform/nixos/* 模块 + 系统服务 | 2–10 min |
| HM          | `home_`        | 41     | QEMU           | home/* 包安装 + 运行时行为     | 2–8 min  |
| Lib         | `lib_`         | 5      | QEMU 256MB min | lib/shared 纯 Nix 表达式       | <1 min   |
| Integration | `integration_` | 1      | QEMU full      | NixOS + HM 联合激活            | 5–15 min |
| **nmt**     | `nmt_`         | **15** | **✗ 零 VM**    | HM dotfile 内容断言（纯 eval） | <10 s    |

**nmt-Plane 特点：** 纯 Nix eval，无 QEMU，无 KVM，利用 `scrubDerivations` 将包替换为 `@pkg-name@` 占位符，避免触发真实构建（白名单外的包一律擦洗）。适合 CI 最快反馈路径。

**nmt vs HM-Plane 互补：**

```
home/core/exp/sys/base/fd.nix
  ├─ nmt_home_core_exp_sys_base_fd     dotfile 内容断言（纯 eval，<10s）
  │    tests/nmt/home/core/exp/sys/base/fd.nix
  │    .config/fd/ignore: .git/ / *.bak 条目
  └─ home_core_exp_sys_base_fd          运行时行为（QEMU VM，~2min）
       tests/home/core/exp/sys/base/fd.nix
       fd --version, fd finds files by pattern
```

**CI 平面整面交接（无需手动维护列表，T7.3）：**

```bash
# 平面成员由 tests/default.nix 的 planes 面声明——新测试按构造落位其平面；
# CI 直接把整面交给 nix-fast-build（从锁定 nixpkgs 解析，零 registry 漂移）：
nix-fast-build --no-nom --skip-cached -j "$(nproc)" \
  --flake ".#api.checks.planes.nixos"

# 平面分组可独立寻址（与 .#checks.<system> 同形态的 derivation 属性集）：
nix eval ".#api.checks.planes.nmt" --apply builtins.attrNames --json
```

**运行命令：**

```bash
# 全量（需要 KVM；深层求值无 KVM 也可跑 --no-build）
nix flake check

# nmt only（最快，无 QEMU）
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]" \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" --no-link

# 单个
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_git -L
nix build .#checks.x86_64-linux.nixos_core_srv_db_postgresql -L
nix build .#checks.x86_64-linux.integration_hm_activation -L

# export/ 模块文档再生（docs.nix 侧通道发射器，T5.3）
nix build .#module-docs    # → result/options/{home-,nixos-}<module>.md + index
```

**nmt 获取机制：** sourcehut 对 Nix fetcher UA 返回 HTTP 403，因此使用 `github:Redskaber/nmt`（mirror）+ `flake = false`，通过 store path 直接引用。`buildHomeManagerTest` 包装器在 `tests/nmt/default.nix` 中自行实现（nmt 原生不提供此函数）。

详见 [`docs/tests/test-matrix.md`](docs/tests/test-matrix.md) · [`docs/tests/nixosTest.md`](docs/tests/nixosTest.md) · [`docs/tests/nmt.md`](docs/tests/nmt.md)

---

## justfile 命令参考

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
> 仓库携带的是**维护者的**密文（对你不可解）——fork 接管流程见 §5 安全层。

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
just secrets-plan-create                # 可选：生成明文模板参考（填写前对照）

nix shell nixpkgs#mkpasswd --command just secret-set-all
# 交互式逐项录入（输入即加密，明文不落盘）；或按需单独：
#   just secret-set userpwd             # 用户系统密码（mkpasswd sha-512）
#   just secret-set nix                 # GitHub access token
#   just secret-set mongodb             # ...

just secrets-verify                     # 收件人一致性审计（期望全绿，红则按提示修）
just secrets-status                     # 三层状态总览（key / rule / blob + 本机 identity）
```

> **个人机同时跑 srv 服务**（dev-on-demand db profile）？Phase 1 用直达双 key
> 引导后，把 host identity 也落位本机：`just key-install-host <alias>`
> ——基线态单把 user key 已够用，但硬化 srv 策略（host-only）与本机独立
> 恢复路径都要求它就位（详见 rotation.md §2b「own host = srv host」）。

### Phase 3 — 首次部署

```bash
just hosts-list                  # 确认主机键（hosts/ 目录数据驱动）
```

**A. 全新 NixOS 机（从 LiveISO 安装）**：

```bash
# 分区 + 挂载后（/ 与 /boot），在目标环境生成硬件配置并安装：
sudo nixos-install --flake /etc/nix-config#<host>
```

**B. 已有 NixOS 系统（接管/切换到本配置）**：

```bash
just nixos-switch <host>         # = sudo nixos-rebuild switch --flake .#<host>
```

**C. 非 NixOS 平台（仅 home-manager 层）**：

```bash
just home-switch <host>          # → <username>@<host>（如 just home-switch wsl）
# macOS: darwin-rebuild switch --flake .#<host>
```

### Phase 4 — 验证与回滚

```bash
just secrets-status              # secrets 三层健康
nixos-rebuild list-generations   # 世代清单（每次 switch 一代）
sudo nixos-rebuild rollback      # 一键回上一代
just nixos-test <host>           # 试验性切换（不写 boot 条目，重启即弃）
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
| 我有哪些加密内容 / 缺哪个 | `just secrets-list` |
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
just key-new-host <alias>              # ① 生成 host keypair（仓外交付副本 ~/Downloads）
just init <username> <alias> <age1…>   # ② 直达 USER+HOST（①打印的公钥传入）
just secret-set-all                    # ③ 录入（srv 域 blob 双收件人）
just key-install-host <alias>          # ④ host identity 合并进本机 key 文件
shred -u ~/Downloads/host-<alias>.age  # ⑤ 本机已持有 identity，销毁交付副本
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
just key-new-host <alias>              # ① 服务器 keypair（你操作机上生成）
just key-add-host <alias> <age1…>      # ② 公钥接线进 .sops.yaml（srv 域）
just secrets-sync                      # ③ 存量 blob 迁移到双收件人
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
age-keygen -o /tmp/new-user.age 2>/dev/null             # ① 新 keypair（仓外）
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
2. **另一域评估**: user 域与 srv 域爆炸半径隔离（§5 安全层）——按失陷的
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
| NixOS x86_64 | 完整   | 完整   | 全部（25 devShells）  |
| Linux x86_64 | —      | 完整（+ nixGL） | 全部          |
| macOS ARM64  | nix-darwin 闭包（eval 级验收，activation 待真机） | 完整（module mode；lean app-set） | CLI 为主 |
| WSL2         | NixOS-WSL 闭包（eval 级验收，T7.1；activation 待 Windows 宿主） | 完整（+ wslview shim，caps.wsl 门控于共享树） | 全部（需启用 systemd） |

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

## 依赖图

```
flake.nix（46 inputs）
├── nixpkgs (nixos-26.05)
│   └── nixpkgs-unstable         # 双通道（shared.upkgs，第二实例非 overlay）
├── home-manager (release-26.05)
├── nix-darwin (26.05)           # darwin 系统闭包（tarball-pinned 规避 api 限流）
├── sops-nix                     # secret 管理（版本锁定）
├── disko (v1.13.0)              # 声明式磁盘分区（tarball-pinned；解释器注册于
│                                #   platform/nixos/core/base/disk.nix）
├── impermanence (7b1d382f)      # 声明式持久状态 / ephemeral root（tarball-pinned 至
│                                #   master HEAD；解释器注册于
│                                #   platform/nixos/core/base/impermanence.nix，T5.14）
├── nixos-wsl (release-26.05)     # 第五系统形态的 WSL 解释器（tarball-pinned 至
│                                #   release-26.05 分支；薄门注册于
│                                #   platform/nixos-wsl/default.nix，T7.1）
├── nix-types                    # enum 类型系统（自建）
├── pdshell                      # devShell 管道引擎（自建；follows nix-types 单源）
├── configuration-orchestrator   # wallust 主题注入引擎（自建）
├── nixgl                        # 非 NixOS GL 修复
├── nur                          # 社区包
├── hyprland                     # Wayland WM（最新版）
│   └── hyprland-plugins
├── pre-commit-hooks (git-hooks.nix)  # pre-commit-check derivation
├── wechat                       # 微信（自建 flake）
├── unrpyc                       # RenPy 反编译（自建 flake）
├── cnmplayer                    # 网易云音乐 TUI（自建 flake）
├── trae / z-library / zcode     # 自建 flake
├── nmt                          # HM dotfile 测试框架（flake=false, GitHub mirror）
├── commit-config                # 提交规范（commitlint + commitizen + husky 规则）
└── *-config (flake=false) ×22   # 各工具配置仓库（外部 Git 源）
    nvim · emacs · vscode · starship · fastfetch · wezterm
    kitty · tmux · mpv · btop · cava · niri · hypr · rofi
    swaync · wallust · waybar · wlogout · quickshell · qutebrowser
    input-overlay · fcitx5
```

---

## 已知边界与设计债

诚实清单——以下是当前已知的边界与待偿债务（修复均有明确路径，不阻塞使用）：

1. ~~**`platform/nixos/core/base/wsl.nix` 处于休眠态。**~~ **已解决（T7.1）。**
   第五 platform 行 `nixos-wsl` 落地（caps.wsl = true 的系统形态），caps 门首次被真实
   主机点亮；同时手写的 WSL 面被移除（wsl.conf/binfmt/getty/resolv 由上游 NixOS-WSL
   解释器单一持有，本仓只保留 chrony 时钟漂移防护的真差量），用户空间 interop 提升到
   共享树（home/core/base/wsl.nix，caps.wsl 门控，两个 wsl 主机单地址消费）。
2. **drive 指纹与策略不同步（hosts/nixos）。** 基策略声明 `drive-group.intel`（单），
   而 `hosts/nixos/default.nix` 仍携带完整的 NVIDIA-Prime offload 指纹块
   （`intelBusId`/`nvidiaBusId`）——它们要等一个 `*-nvidia-prime` drive-group 行被
   选中才会生效。指纹是无害的提前声明，但读者应知道它当前是惰性的。
3. ~~**display-manager 枚举无 `none` 行。**~~ **已解决（T7.1）。** 枚举加行 +
   `platform/nixos/dm/none/` Null-Object 模块（与 window-manager none 同构：存在性
   保持路由无条件）；系统侧 wm/none 同步补齐——hosts/nixos-wsl 的控制台形态需要
   「无 DM、无 WM」的完整语法。
4. **darwin `system.stateVersion = 6` 是整数。** nix-darwin 的该选项接受整数
   （与 NixOS 的字符串不同），这是一个已知的类型怪癖，已在 hosts/darwin/default.nix
   注释中说明。
5. ~~**standalone HM 发射器的 pkgs 取自基策略实例。**~~ **已解决（T7.2）。**
   mkHomeSystem 现在读取主机自身策略实例的 pkgs（`pkgs = hshared.pkgs`，targets.nix）——
   运行时层本就按主机 arch 实例化 nixpkgs（`pattrs = { system = arch.tag; } ⊕ nixpkgs
   策略`），发射器如今与之对齐：未来的 aarch64-linux standalone 主机按自己的 arch 求值。
   对现有全部主机字节恒等（三个未动 HM 闭包 drv 哈希逐一验证——本修复是可表达性，
   不是行为变化；hm-vm 的偏移全部归因于同一提交的 wm 翻转）。
6. ~~**vm 继承基策略的 hyprland + ly。**~~ **已解决（T7.2）。**
   hosts/vm/shared.nix 覆写 wm/dm 两行 none：server-pg-only 形态不再携带永不启动的
   桌面闭包。桌面栈整体减除（hyprland / ly / portal 中介 / flatpak / gvfs / tumbler
   全 off），机器故事无损（btrfs ephemeral root、/persistent、postgresql 探针逐一
   保持）；vm 求值 12.4s→9.6s，hm-vm 包集 140→114。
7. **eval 成本记录。** nixos toplevel 求值 ~16.8s（disko extendModules 选项树
   +1.5s 已记录在案）；vm toplevel 求值 ~9.6s（T7.2 控制台化后自 12.4s 降——桌面
   模块树离开了 vm 的选项宇宙）；六闭包顺序求值 ~65s（T5.10 后自 90s 降）。单进程
   全输出 `nix flake check` 在 4GB 内存沙箱会 OOM（六 OS 级模块宇宙的内存地板，
   与策略实例数无关）——CI 以分 job 方式规避。
8. **boot 级与真机验收待环境。** 第二台机器 boot 级验收（KVM/真机，含 T5.14 ephemeral
   root 的回滚真机验收——求值/构建级已全绿：配方派生/双 initrd 模式/惰性律由
   nixos_core_base_impermanence 锁定，formatMount 真实构建，但「每次启动根被归档重建」
   本身需要一次真实 btrfs 启动）、macOS activation（真 Mac）、hosts/nixos 的 disk.nix
   应用（重装时机）——四者都已有完整路径，等待对应环境。
9. **sound 栈无能力位门控。** sound.nix 的 pipewire/alsa/pamixer/pavucontrol 不读
   任何能力位——vm / nixos-wsl 控制台形态同样携带。T7.2 巡检发现但刻意缓议：音频
   是否属于「无桌面会话也保留」的能力（QEMU 音频设备、WSLg 经 pulse 的 Windows
   桥）需要真机语义裁决，与 #8 同属环境门控类；首次真机验收时一并决定门控与否。

---

## 路线图

- [x] CI 全量 build 验证（nmt-Plane + QEMU VM tests，7 阶段流水线）
- [x] NixOS 测试套件（91 checks = 90 tests + 1 pre-commit-check〔内含 nixfmt/statix/deadnix 三钩子〕，6 个测试平面）
- [x] flake inputs 自动更新策略（定时 PR，每周日）
- [x] platform/ 平台分发层（nixos · linux · darwin · wsl，arch 路由）
- [x] api.inputs 暴露（just 脚本动态枚举 inputs，零硬编码）
- [x] AI CLI 工具集成（claude-code · opencode · gemini-cli · kiro-cli · cursor-cli · pi-coding-agent）
- [x] kiro 编辑器集成（home/core/exp/app/editor/kiro.nix）
- [x] nmt mirror 解决方案（sourcehut 403 规避，buildHomeManagerTest 自实现）
- [x] sops 数据驱动架构（零硬编码路径，phase-aware 信息源分离）
- [x] secrets just 生命周期重设计（T5.0：仓库出厂态 = EMPTY——`.sops.yaml` 与密文 blob 全部由 just 流程生成（`secrets-init`/`secret-set`）后入库，不携带预置密钥材料；动词面按三对象重组 secret-*/key-*/rules-* + 注册表驱动（12 个 per-secret recipe → 1 张别名表）；`just`（裸）= start-here 地图 + `[group]` 分组的 `just --list`；eval 期 resolution pass 对 EMPTY 态宽容（零 blob → trace 引导，≥1 blob → 严格 declared-but-not-provided）+ fixture 化契约测试；CI security 全步骤 EMPTY 容忍；README 多情景手册（9 情景 × 速查表）+ 全流程文档同步）
- [x] tools.nix 工具库统一管理（nix-types / orc / pdshell 短路径访问）
- [x] hosts/ 多主机支持（per-machine facts + overrides；facter/disko 声明式形态，T5.12/T5.13）
- [x] service-profile 按需启动（install vs autostart 分离，dev-on-demand / full-autostart / server-pg-only / minimal）
- [x] editor-set / terminal-set / browser-set 集合路由（多选路由模式）
- [x] version 策略携带（variant 携带 {stateVersion, wine, swww} 策略）
- [x] shellIntegrations 统一（runtime 计算，8 个 base 模块复用）
- [x] match 穷尽性（nix-types lib.match 替代手写 if）
- [x] 分发层收敛（T4.0：enum.platform 能力表 caps + 策略载荷；全树消灭叶子级 if-else/谓词重复推导/tag 比较；schema 嵌套默认值物化修复；变异验证 ×2 + 六配置求值级行为保持——home×3/darwin drv 字节一致）
- [x] 入口清爽化（T5.1：flake.nix 只保留输入声明 + 协议名映射；主机清单→caps 分类→closure 发射器全部移入 lib/shared/targets.nix 生产端——编译器后端 pass；根目录 darwin/ 并入平台树，host-dispatch 层一个平台一个目录；pre-commit 配置移入 tests/pre-commit.nix）
- [x] 中间层命名收敛（T5.2：lib/shared/shared → lib/shared/lang——语言前端层（类型/枚举/schema/验证，无 pkgs），消除路径重复命名；三段式镜像编译器管道：lang（frontend）→ runtime（IR 合成）→ targets.nix（codegen）；`shared` 逻辑名保持为全树稳定线协议，测试镜像与 check 名同步 lib_shared_lang_*）
- [x] pre-commit-hooks（nixfmt + statix + deadnix 自动检查）
- [x] services.just 按需启动命令（service-start/stop/status + db-start/stop/list）
- [ ] 第二台机器测试（验证跨机器可移植性，scfpath 多机器场景）（T2.3-T2.5：hosts/vm 策略链已通，双机求值级验收完成；boot 级验收待 KVM/真实环境）
- [x] 惰性模块加载（T5.10：两 pass 一 commit——**Pass A 策略 IR 单实例化**（分发层 CSE：mkShared 每 flake 求值 ~23 次 → targets.nix 建 `sharedByHost = genAttrs hostNames mkShared` 单表，分类器/发射器/命名/别名全部读表；默认主机表项 = 基实例〔句柄共享即不为默认主机付两次费〕；flake.nix 基 shared 改 consume `targets.base`；遗留别名从重发射改为 attr 级 thunk 别名〕。**Pass B app-set 需求驱动模块装载**（app 树重量级轴：editor/browser/terminal 三选集回答"已路由目录内选哪些叶"，app-set 回答"app 树里哪些目录为该主机存在"——full〔16 目录，顺序即旧静态 import 表，enum 测试锁定防序漂移〕/ lean / none；runtime 发布 `appCategories` 展平句柄；wps-office-cn 补 linux-family caps 门〕。**验证**：hm-nixos nqvaivz 字节一致；hm-vm/hm-wsl 各 −55 包、darwin −12 包〔包集 diff 穷尽归因于被剪目录贡献〕；六闭包顺序求值 90s→65s）
- [x] 模块文档自动生成（从 Nix 模块 options 生成）（T5.3：lib/shared/docs.nix 侧通道发射器——HM 域共享基础 option 集 + NixOS 域全量 eval-config 单次求值，namespace 过滤只保留 redskaber.*，域前缀六份 CommonMark + index；`nix build .#module-docs` 一键再生）
- [x] darwin 平台调用机制统一（T5.4：分发层发射器全部目录导入；platform/darwin/default.nix 补齐 arch 路由器，HM payload 迁至 aarch64-darwin.nix；三 closure + 双 HM drv 哈希字节级一致验证）
- [x] darwin 发射器装配内聚（T5.5：home-manager.darwinModules.home-manager 从 mkDarwinSystem 的 modules 列表移入平台树内 imports——darwin 系统形态拥有自己的 HM 集成；三类发射器收敛为完全同构的单行目录引用）
- [x] 平台架构完成：nixos 系统树归位（T5.7：根级 nixos/ 树 → 平台目录内——「一平台一目录」补全；系统海关与 HM 海关按域分立；hosts 路由与 tests 镜像同步；72 文件 @path/@description 头部同步）
- [x] darwin 单门折叠：default.nix 即边界海关（T5.8：platform/darwin 的系统装配折叠进 default.nix，arch 分发同文件内联；折叠可行性判据 = 活门计数——darwin 单活门 → 单文件海关；nixos 双活门 → 不可折叠〔单文件双域需 options 存在性嗅探 = 配置层 if-else，被禁〕；「每活门一海关」成为平台目录布局的第一性判据）
- [x] 平台目录语法 v2：文件名即域（T5.9：消灭 default.nix 同名异义——看文件名即知域；目录语法四轴归一——系统层|用户层 · 平台-架构 · 分发层级 · 职责边界；文件存在性 = 能力声明〔caps 表在文件系统的投影〕；结构零行为变更：76 文件 rename/路径同步，四闭包 drv 哈希与基线字节一致）
- [x] 平台目录语法 v3：目录即域（T5.11：用户域获得自己的层级——platform/&lt;tag&gt;/home/ 子树〔唯一保留的顶层名〕，HM 海关 home/default.nix、payload home/&lt;arch&gt;.nix〔arch 轴在用户域内获得地址〕；darwin payload 归位用户域子树，系统关挂载行 `users.&lt;u&gt; = import ./home/${arch.tag}.nix` 使跨域引用在路径上可见；三发射器统一目录引用；hosts/ 驻留根的裁决固化〔前端源树 vs 后端能力树，层不倒置〕；求值级等价验证：四闭包 drv 哈希与基线字节一致，nixos/vm 差异漏斗溯源闭合于 flake self 快照〔树哈希因 rename 变化，语义零变化〕）
- [x] export/ 模块完善（T2.1 首批五组：portal / fcitx5(nixos+home) / shell / waybar / yazi，options-first + 外部导入验收测试；接口规范见 docs/modules/interface-standards.md）
- [ ] macOS 完整支持（darwin-specific modules，nix-darwin 集成）（T3.2：darwinConfigurations.darwin 全闭包求值级验收完成——nix-darwin 26.05 + hm module mode；activation 待真实 Mac）
- [x] 策略表补全（T7.2：**vm 瘦身**〔债 #6〕——hosts/vm/shared.nix 覆写 wm/dm 两行 none：server-pg-only 形态不再携带永不启动的桌面闭包，桌面栈整体减除〔hyprland·ly·portal 中介·flatpak·gvfs·tumbler〕、机器故事无损〔btrfs ephemeral root / /persistent / pg 探针逐一保持〕、vm 求值 12.4s→9.6s〔−23%，桌面模块树离开选项宇宙〕、hm-vm 包集 140→114〔−26〕；**standalone 发射器按主机 arch 解析 pkgs**〔债 #5〕——mkHomeSystem 改读主机自身策略实例的 hshared.pkgs〔运行时层本就按 arch 实例化 nixpkgs〕，aarch64-linux standalone 从此可表达；三个未动 HM 闭包 drv 字节一致〔nqvaivz·8b0srg82·sd3d2kx9〕——可表达性修复零行为变化；**策略行巡检三发现**——① portal.nix 无 desktop-session 门〔控制台形态携带 xdg-desktop-portal+wlr portal，与 home 侧 none 策略的设计矛盾〕→ 门控于 window-manager 枚举的 desktop-session 能力位〔T4.0 定律：读已解析事实，非原始 tag 比较〕；② srv/desktop/ 组〔flatpak+file-manage〕同为桌面会话服务，且 flatpak 的 nixpkgs 断言硬依赖 xdg.portal.enable〔门控 portal 后断言立刻爆出——求值级验证电池抓到的真缺陷，两模块共读同一能力位修复〕；③ sound 栈无门控但刻意缓议〔WSLg/QEMU 音频语义需真机裁决，新债 #9〕；**新测试 nixos_core_base_portal**〔export-modules 模式：desktop 形态门开 + 真实 vm 机经 mkShared 同构构造——门控双律 + 债 #6 减除全谱 + 机器故事存活；断言强制经变异验证〕；93 checks〔92 tests + 1 pre-commit〕；裸金属 nixos 探针字节一致〔门控对桌面形态=恒等——mkIf true 语义〕；T7.1 的两处枚举成员表残留顺手修复〔platform 行补 nixos-wsl、display-manager 行 none 注记〕）
- [x] CI 构建深度（T7.3：**测试矩阵双面化 + nix-fast-build 整面交接**——tests/default.nix 返回值从单一平铺 attrset 升级为 `{ checks, planes }` 双面〔同一组成员 thunk、两种寻址零额外求值——T5.10 单实例化纪律〕：平铺面仍由 `checks.${system}` 消费〔`nix flake check` 要求每属性恰一个 derivation——中断会话留下的嵌套结构会让 checks 输出含非 derivation 成员，硬门禁必炸〕，平面面经 `api.checks.planes` 暴露〔六平面分组 = 分类法自身的分组〕；**CI 两阶段转换**——STAGE 3 nmt-plane 与 STAGE 6 vm-tests 的前缀发现 + 顺序循环全删〔python 前缀过滤 + 逐个 nix build 共约 90 行〕，改为 `nix-fast-build --flake .#api.checks.planes.<plane>`〔nix-eval-jobs 并行求值 + 流水线构建；`--skip-cached` 对接 magic-nix-cache；`-j $(nproc)` 显式并行——1.4.0 默认继承 Nix max-jobs=1，不传即退化串行〕；**确定性供应链**——nix-fast-build 从锁定 nixpkgs 解析〔`nix eval --raw .#api.inputs.nixpkgs.outPath` → store path 作 flake ref〕，与 flake 同一 revision，零 registry 漂移、零新输入〔T6.3 裁决的采纳落地；1.4.0 + 捆绑 nix-eval-jobs 2.34.3，`-f` 任意 attrpath / `--force-recurse` 递归 / 无 system 后缀逻辑——语义经知识搜索对上游 1.4.0 tag 源码核实〕；**矩阵 4→5 腿**——home-lib 合并腿拆开〔每腿恰一平面，平面面成为 CI 分区 SSOT——新测试按构造落位其平面，CI 侧零维护〕；lint 阶段平面计数同改读 planes 面〔不再前缀重推导〕；**顺手修复**——vm-tests 的 `::add-mask::$AGE_SECRET_KEY` 引用错误〔env 实为 SOPS_AGE_KEY——旧代码掩码的一直是空串〕；**验证**——等价断言〔平铺−pre-commit ≡ 六平面之并且逐平面 ≡ 旧前缀过滤结果，无交叠分区：1+29+41+5+1+15=92〕、六平面可独立寻址、93 checks 深层求值全绿、YAML 解析通过、锁定 nix-fast-build `--help` 实测旗标齐备〔--no-nom/--skip-cached/-j/-f〕；对标 Mic92 CI 的构建深度达成——闭包级构建（真 toplevel 构建深度）仍属环境门控〔CI 无 KVM 全档或自托管 runner 时再议〕）
- [x] docs-SSOT 计数契约（T8.1：**计数从「人工同步」升级为「机器强制」**——tests/docs-ssot.nix 入列 checks 第 94 员〔pre-commit-check 的同位仓库卫生门〕：活值从求值取〔tests 92 / 平面 1+29+41+5+1+15 / inputs 46〔`@inputs` 捕获含 self 注入故扣除〕/ devShells 25 / hosts 5——attrNames 与 mapAttrs，永不解析散文〕，19 个规范锚点在 README 与 test-matrix 构建期断言〔散文锚 grep -F、表格行 grep -E 填充容错〕；模式来源 wimpy `checks.assistant-catalogue` 的逆向适配——断言内嵌而非生成对拍〔本仓 README 是手写散文非生成物，只锚规范声明、刻意不锚每处散文提及——锚全部句子会让 README 不可编辑〕；**设计期即抓四处真实漂移**〔devShells 速查表缺 makeOs 行而活值 25、test-matrix 3.1 节头滞留 24、3.3 节头滞留 3、3.2 节合计 36 缺 export 行〕——全部修复；**构建期强制**〔deep-eval 只求值〔runCommand 恒构造〕，锚点断言在 build 时触发——CI STAGE 1 在 pre-commit-check 旁显式构建，计数漂移即红灯〕；flake.nix 接线〔checks = tests // pre-commit // docs-ssot 三段合并 + pdsh hoist 单次构造双消费 + inventory/devShellNames 传参——键级求值零额外成本，T5.10 纪律〕；**验证电池抓真缺陷**：首版裸返回派生体 → `//` 把 drv 属性泼进 checks 面〔outPath/__structuredAttrs/userHook 混入且成员丢失——pre-commit.nix 头警示过的同类〕→ 面求值 138 员立刻暴露 → 包裹 `{ docs-ssot-check = …; }` 修复后恰 94 员零泼洒；变异验证〔box 94→93 → 构建 FAIL 带可操作信息；复原 → 绿〕；五闭包字节一致〔nqvaivz·s61py9qg·8b0srg82·sd3d2kx9·dqhyw65——检查对主机/HM 闭包零扰动〕；test-count.sh 权威让位〔本地速查保留，公式 +1→+2〕；钉版 pre-commit-check 构建绿）
- [x] CI 主机闭包构建腿（T8.2：**构建深度从「测试平面」升级到「真系统闭包」**——api.host-toplevels 第五 api 面〔inventory 数据驱动：nixosHosts 枚举——nixos · vm · nixos-wsl，新 NixOS 主机按构造入列，零 CI 侧维护；成员 = `nixosConfigurations.<h>.config.system.build.toplevel`——与深求值同一 thunk，T5.10 单实例化〕；CI STAGE 6.5 新腿〔needs lint+deep-eval；与平面腿同工具同纪律——锁定 nixpkgs 解析 nix-fast-build、整面交接、`--skip-cached -j $(nproc)`；可行性依据：cache.nixos.org 同 revision 替代 + magic-nix-cache 跨次缓存〔Mic92/wimpy 同型先例〕；darwin 跨系统闭包显式求值步〔aarch64-darwin 构建需 darwin runner/交叉工具链——环境门控，路径已备〕〕；**T7.3 裁决升级**〔当时「闭包级构建属环境门控」的缓议，经 8-a 评分刷新认定 stock runner + 替代缓存即够——缓议条件不成立故升级，非推翻〕；summary 表 + 分支保护清单同步；流水线 7→8 阶段（ci.yml 头注释 + README 三处）；api.* 接口文档补第五面；验证：api.host-toplevels 三成员求值绿 + 与深求值同源、五闭包字节不变、YAML 解析 + bash -n、nixfmt + 钉版 pre-commit 绿〕
- [x] nixos-facter 替代 nixos-generate-config（声明式硬件发现）（T5.12：硬件事实从「生成的 NixOS 模块」升级为「数据 + 解释器」——hosts/&lt;h&gt;/facter.json 是标准 facter 报告〔schema version 1，与锁定 nixpkgs 的 nixos-facter 0.4.4 一致〕，由 nixpkgs 默认模块表内的 `hardware.facter` 模块解释，主机入口一行接线——零 import、零 flake input；**模块上游化裁决**：nixos-facter-modules 仓库已弃用并入 nixpkgs，本项目不加输入直接消费；hosts/vm 全量迁移〔VM 硬件本是被定义的：QEMU x86_64 PCI guest——kvm 虚拟化、virtio-blk 盘 + 存储控制器、virtio-net 网卡、无 vmx/svm 的 vCPU；报告由声明而非探测产生，字段与真实报告逐一对齐〕；解释器职责边界固化：fileSystems 非报告职责〔上游留待 disko〕、network_interface 刻意不列〔NetworkManager 策略拥有 DHCP——CONTROLLER 在报告中，驱动照样进 initrd〕；真实机器〔hosts/nixos〕迁移路径落地：`just hardware-facter`〔root 扫描生成报告〕+ README 迁移指南；求值级等价验证：vm 配置 diff 穷尽闭合于三处 facter 解释，其余四闭包 drv 哈希字节一致）
- [x] disko 声明式磁盘分区（替代 hardware.nix 里的 fileSystems 硬编码）（T5.13：磁盘事实从「手写 option 赋值」升级为「数据 + 解释器」——hosts/&lt;h&gt;/disk.nix 是 disko 布局声明〔GPT + EF02 BIOS boot 1MiB + root ext4 100%，上游 gpt-bios-compat 形态〕，由 disko 模块解释为 fileSystems + swapDevices + boot.loader.grub.devices；**注册裁决**：disko 不在 nixpkgs〔已对锁定 26.05 树核实〕，新增 flake input〔tarball-pinned 至 v1.13.0；follows 本仓 nixpkgs 单通道〕，模块 import 落 platform/nixos/core/base/disk.nix——能力归平台结构树、数据归 hosts/，分发层与发射器零改动；hosts/vm 全量迁移 + 引导策略对齐〔grub on / systemd-boot off〕；求值级验证：vm 配置 diff 穷尽闭合于六处，hosts/nixos 配置零变化〔模块惰性〕；四闭包字节一致；构建级探针：formatMount 脚本真实构建成功；顺带修复存量缺陷：T5.2 改名残留的四处测试引用 + 两处文档引用〔nix flake check 自 T5.2 起即坏〕，89/89 checks 现全绿；just 新增 disk 组动词〔disk-show/disk-format〕）
- [x] Option/Result 类型化错误处理（T4.1：secret 路径校验用 result.andThen —— nix-types Result 铁路〔shared/validate.nix〕：形状检查前置 pass 折叠 + 文件系统存在性 resolution pass + unwrapOrElse 单一边界 throw；声明而缺失的 secret 在 eval 期报「declared but not provided」；变异验证 ×2 + home×3/darwin drv 字节一致）
- [x] 可观测性（prometheus exporters + loki 日志 + grafana dashboard）（T3.4：service-profile 携带 monitor 策略，三档 profile 求值级验收 + nixos_core_srv_monitor_policy 测试）
- [x] 健康检查（数据库服务加 systemd HealthCheck）（T3.4：双层——Restart 自愈兜底 + 30s liveness timer 探活，60s 可观测窗口，变异测试验证）
- [x] 树卫生：让树说真话（T6.1：死模块清扫——platform/nixos/core/exp/xwayland.nix 自创建起从未被 imports〔全历史 -S 搜索证实〕，且 `programs.xwayland.enable` 本就是 nixpkgs 默认值、hyprland 行有自己的原生 xwayland 开关——三重冗余的不可达文件，删除〔其存在恰是 v3 文法"文件存在性=能力声明"的反面谎言〕；72 文件 @description 头部 de-drift——pre-T5.9 的 `system::` 段残留，@path 已更新而 @description 未随；SSOT 计数器修复——test-count.sh 自 T5.1〔hooks 块移入 tests/pre-commit.nix〕起即崩〔AttributeError〕，计数器跟随移动 + runner regex 清理〔runTest/nmtTest 已被 deadnix 移除〕，现输出与 CI summary 对账一致；flake.nix 陈旧注释修复——"unstable-packages overlay" 不存在，unstable 是 shared.upkgs 第二实例；chmod.sh / hosts/darwin/shared.nix @path 漂移修复。验证：四闭包〔hm-nixos nqvaivz · hm-vm ddm2ifj · hm-wsl 4ih8pc4 · darwin dqhyw65〕字节一致；vm/nixos 配置值探针全同〔hypr/ly/dm/fs/grub/sb/nm/pg/hs/xway/nvidia/state〕——注释级改动零配置影响，drv 变化经 self 树哈希归因；nixfmt 干净）
- [x] README 全量重构（T6.2：三路勘察〔平台树 81 文件 / hosts+home+tests+scripts 全量清点 / 旧 README 逐行 gap 分析〕驱动的完整重建——保留精华段〔设计原则 / 架构总览 / 安全层 / hosts 故事 / 快速开始 / secrets 手册 / 路线图〕，修正全部陈旧点：计数对齐 SSOT〔90 checks = 89+1；平面 1/26/41/5/1/15；81 recipes / 13 组；24 devShells；43 inputs / 24 flake=false〕、删除已死 API〔isNixOS/isMacOS/isLinux/isWSL 谓词 T4.0 已删；mkDevShell 实为 mk-pdshell〕、路径全部指向 v3 文法位置、CI 从 6 阶段改为 7 阶段〔deep-eval 硬门禁——旧"CI 不跑 flake check"注意事项已被 validate.nix Result 铁路消除〕、devShells 表补全 24 行〔asm/makeOs/rs_compiler_dev/nix-nonfmt〕、依赖图 26.05 化 + 补 disko/nix-darwin/zen-browser/trae/z-library/zcode/pre-commit-hooks、EMPTY 态声明改为"仓库状态 vs 采纳者引导"的诚实框架〔本仓库携带维护者密文〕、部署示例统一 canonical `.#nixos`；新增三节：**目录语法**（文法六律 + 四平台形态表 + "为什么 nixos 不折叠双门"论证）、**分发层 targets.nix**（三段流水 + T5.10 单实例化故事，原散落在架构总览与路线图之间的机制知识首次获得自己的机制节）、**已知边界与设计债**（8 条诚实清单：wsl.nix 休眠态、drive 指纹惰性、DM 无 none 行、darwin stateVersion 整数怪癖、standalone pkgs 基实例 caveat、vm 桌面闭包、eval 成本记录、boot/真机验收待环境）；runtime 字段表补全 T4.0/T5.10 后的真实字段〔caps/i18nScope/services/appCategories/shellIntegrations/provenance/editors/terminals/browsers〕；fn 示例替换为真实导出面〔homeDir/sopsBase/sopsFile/sopsRuntimePath/pkgsFingerprint/sameSource〕；api.* 三接口成文〔inputs/shared/targets〕；`nix build .#module-docs` 入命令参考）
- [x] impermanence 实验性 ephemeral root（btrfs subvol rollback）（T5.14：hosts/vm 升级为 ephemeral-root 机器——**第三事实对**：hosts/&lt;h&gt;/persist.nix 是状态策略数据〔「根是 ephemeral」的机器事实 + environment.persistence 生存清单〕，解释器 = `platform/nixos/core/base/impermanence.nix`（注册 impermanence 模块 + 从布局已声明事实**派生**回滚配方，无任何手抄脚本：device/fsType/subvol 读自 disko `_config` 输出〔IR 消费〕，retain-days 是唯一自由参数〔默认 30〕）；hosts/vm/disk.nix 同步升级 root ext4 → btrfs **四 subvol 四寿命**：root（/，ephemeral——每次启动归档到 old_roots/&lt;timestamp&gt; 并重建为空）/ persistent（/persistent，状态——PostgreSQL 数据等）/ nix（/nix，store 闭包存续 + compress=zstd）/ boot（/boot，引导链——内核与 grub.cfg 绝不随根蒸发〔本设计要避开的陷阱〕，grub 从 btrfs 顶层视图寻址 subvol 即目录）；**配方是上游权威内容**（impermanence README.org "BTRFS subvolumes" 节）+ 两处引用在案的结构化改造：事实插值化、顶层视图挂 `-o subvol=/`〔disko 自身 `_create` 的约定〕；**双 initrd 模式分派**（求值验证第一轮即抓到 vm 为 systemd stage 1 而 `postResumeCommands` 不存在于该模式——nixpkgs eval 期断言）：systemd 模式 = sysroot.mount 之前 oneshot〔门在根设备 unit 上，systemd-repart 先例；DefaultDependencies=false〕，classic 模式 = postResumeCommands〔根挂载循环之前，锁定 26.05 stage-1-init.sh 执行序已核实〕；btrfs-progs 进 initrd 零手接线（nixos btrfs task 模块从 fileSystems fsType 自动推导）；**上游化裁决**：impermanence 而非 preservation〔nixpkgs-track 后继者〕——两者均不在锁定 26.05 树，T5.12 零输入先例不适用，实验面向最实战验证模块，preservation 落地 nixpkgs 后按 T5.12 先例迁移〔清单数据与回滚机制不受影响〕；tarball-pinned master HEAD 7b1d382f + follows nixpkgs；解释器契约：上游「persistence 路径必须 neededForBoot」断言以 mkDefault 满足 + 本仓更严一条「persistence 路径必须是已声明 mount」〔布局缺口大声失败〕；测试 `nixos_core_base_impermanence`〔export-modules 模式：三组独立 nixosSystem 求值——systemd/classic/inert，求值期断言锁定配方插值/单元排序/设备门/neededForBoot/bind mounts/惰性律〕；just 新增 `persist-show`〔disk 组，82 recipes〕；求值级验证：vm 探针全绿〔btrfs+subvol=root/postResume 空/服务排序 dev-disk-by\\x2dpartlabel device unit/neededForBoot/bind mounts〕、hosts/nixos 配置探针零变化〔模块惰性〕、四闭包字节一致；构建级探针：formatMount 真实构建 + 产物抽查〔mkfs.btrfs by-partlabel + 4×subvolume create〕；91 checks〔90 tests + 1 pre-commit〕；boot 级验收待 KVM〔已知边界 #8〕）
- [x] nixci 路线图项审查裁决（T6.3：**移除而非延期**——四点证据链：① 工具已被上游废弃，nixci 官方 README 顶部警告 "superseded by omnix"，后继能力是 `om ci`，社区对「并发构建全部 flake checks」的活跃推荐是 Mic92/nix-fast-build〔nix-eval-jobs 并行求值 + 构建，disko 案例 1:54 → 10s〕；② 范畴错配——上述工具的操作对象全部是 flake outputs〔packages/checks/nixosConfigurations…〕，而本仓 24 个 `flake = false` 输入是纯数据树〔无 flake.nix、无 outputs〕，「构建它们的 flake 产物」不存在可作用的对象〔原条目写作 "30+"，实际 24——一并修正〕；③ 真实需求已被覆盖——外置仓库以锁定 revision 被 25 个消费点引用〔`xdg.configFile."x".source = inputs.x-config` 形态，遍布 home/ 树〕，deep-eval 硬门禁求值 91 checks 即强制 fetch 全部输入，nmt 平面物料化 home 激活，VM 平面真实启动含这些配置的系统——update-flake.yml 开出的每个 PR 都跑这条流水线，外部仓库坏提交在合入前即被拦截；④ 职责边界——外置仓库自身的语言级 CI〔stylua/elisp lint 等〕归各仓库所有，本仓是消费者而非所有者，替 24 个异构语言仓库维护 CI 模板违反生产者-消费者边界；本仓自身闭包构建加速若成为痛点，采用项应是 nix-fast-build〔并发构建 checks，替代 CI 中顺序 while 循环〕，与外置输入无关；裁决记录见下方「被拒绝项」小节）
- [x] nix-types 上游贡献（schema pattern matching 模式文档化）（T6.4：`docs/PATTERNS.md` 于 nix-types 仓库成文〔本地 clone commit 61bc6ce，基于 v3.5.0/815fc3f，440/440 测试通过后提交——沙箱无 GitHub 凭据，push 由仓库所有者一步完成〕——P1「Schema pattern matching」：enum-as-schema〔postable 变体携带 payload 记录，声明即封闭宇宙〕+ match-as-exhaustive-dispatch〔无通配站点必须回答每个变体，缺失 case = eval 期 throw 点名变体〕+ 可选 Result 铁路〔校验 pass 以 ok/err 值组合，单一 throw 在边界〕；**库保证 vs 使用纪律分离表**——穷尽性诊断/变体名通配与保留字拒绝/payload 逐字携带是库保证，payload 记录形状跨变体一致性是纪律〔由本仓 90 测试求值电池锁定为回归门〕；规则与反模式成文〔封闭集合专用；通配仅限刻意兜底；Null-Object 成员优于通配；叶子是 codegen；测试上锁〕；生产案例 = 本仓分发层骨干〔4 平台能力表 + 版本策略枚举 + secret 路径 Result 校验〕；**全部代码示例经真实求值验证**〔match 分派/payload 经 value 访问/foldl' 与 andThen 参数序/tryEval 穷尽拒绝探针〕；nix-types 侧同步：README 新增「Consumption patterns」节 + 项目布局条目 + CHANGELOG 3.5.1 条目〔纯文档，零库改动〕；nix-types 输入无需 bump——纯文档提交，库面零变化）
- [x] NixOS-WSL 第五系统形态（T7.1：**评分驱动的下一阶段首项**——同类配置对比显示平台矩阵是最大可行动短板〔WSL2 行系统层为 —，同类旗舰 16–22 主机〕，且设计债 #1/#3 同根。**第五 platform 行而非主机级 caps 覆写**：enum.nix 能力表加 `nixos-wsl` 行〔caps：linux-family ✓ nixos-system ✓ wsl ✓ darwin ✗〕——schema 的文档化演进路径〔"新增平台 = 写一行"〕首次被完整行使；社区先例核实〔moni-dz 主机旗标模式、无旗舰运行 WSL 主机——但对本仓文法，行是 schema-忠实解，主机旗标会破坏"platform 行固定 caps"的 T4.0 不变量〕。**薄门设计**：platform/nixos-wsl/default.nix = `../nixos` 复用 + NixOS-WSL 解释器 + wsl.enable/defaultUser——读门即知形态定义〔nixos customs + WSL 解释器〕；home/ 用户域 payload 行回用 nixos 行〔wrapper：单行 re-export + fork-on-demand 缝〕。**所有权边界重划**：上游解释器拥有 wsl.conf/systemd 托管/interop+binfmt/boot 削减〔手写面全删——单一所有者规则〕；本仓真差量 = chrony 时钟漂移防护〔wsl.nix 瘦身〕；用户空间 interop〔wslview/WSLENV/USERPROFILE/BROWSER〕提升至共享树 home/core/base/wsl.nix〔caps.wsl 门控——两个 wsl 主机单地址消费，平台行只留 non-NixOS-Linux 事实：genericLinux+nixGL〕。**前置补全**：display-manager 枚举 none 行 + dm/none、wm/none 系统侧 Null-Object〔控制台形态的完整语法〕；boot.nix/memory.nix 裸金属值 mkDefault 化〔基础声明默认值、形态合法削减——优先级展开即设计〕。**主机数据**：hosts/nixos-wsl/ 五号机〔default.nix：唯一机器事实 = arch——无 facter〔硬件归 Windows 宿主〕/无 disk.nix〔rootfs 是 Windows 管理的 VHDX，disko 语义不适用〕/无 persist.nix〔WSL 根上 ephemeral 无意义——全部以缺省为数据〕；shared.nix：第五行翻转 + dm/wm none + lean 集〕。**零发射器改动**：分类/路由/双门全程由 caps 表驱动——nixosConfigurations.nixos-wsl 与 homeConfigurations.kilig@nixos-wsl 落地无一行 targets.nix 修改。**验证**：表单探针全绿〔wsl.enable/defaultUser/tarballBuilder/boot 削减〔grub·sdb·initrd·kernel·pm 全 false〕/chrony/无 DM·WM·xserver/hostName·stateVersion·user〕；26 项裸金属探针字节一致〔mkDefault 值保持验证〕；darwin·hm-nixos·hm-vm 三闭包字节一致；hm-wsl 偏移穷尽归因〔wslview 在 home.packages 合并序位 77→43，集合恒等，激活语义不变——模块真实迁移的预期位移〕；caps 真值表测试加第五行〔穷尽性+策略选择〕；新测试 nixos_core_base_wsl〔表单求值〔以 mkShared 同构构造真实主机策略链〕+ 惰性律；断言强制经变异验证〕；92 checks〔91 tests + 1 pre-commit〕；boot/activation 级验收待 Windows 宿主〔环境门控类，与 #8 同〕）

### 被拒绝的路线图项（裁决记录）

路线图只保留真话——被拒绝的项在这里留下证据链，而不是静默消失（"让树说真话"的同一纪律）。

**nixci 统一管理 flake=false 外置配置仓库 CI**（2026-10 审查后移除）：

1. **工具废弃。** nixci 官方 README 顶部警告："nixci has been superseded by
   omnix; you should use `om ci` instead"。对「并发构建全部 checks」的社区活跃
   推荐是 [Mic92/nix-fast-build](https://github.com/Mic92/nix-fast-build)
   （nix-eval-jobs 并行求值 + 流水线式构建）。
2. **范畴错配。** 这些工具的操作对象全部是 **flake outputs**；本仓 24 个
   `flake = false` 输入是纯数据树（无 flake.nix）——不存在可构建的 flake 产物。
3. **需求已被现有 CI 覆盖。** 外置仓库以锁定 revision 被 25 个消费点引用；
   deep-eval 硬门禁求值 91 checks 强制 fetch 全部输入，nmt 平面物料化 home 激活，
   VM 平面真实启动含这些配置的系统——update-flake.yml 的每个 PR 都跑这条流水线。
4. **职责边界。** 各仓库自身的语言级 CI（stylua / elisp lint 等）归各仓库
   所有者——消费者不拥有生产者的生命周期。本仓自身闭包的构建加速若未来成为
   痛点，采用项是 nix-fast-build，与外置输入无关。

---

> 每个目录是一个模块，每个模块是一个函数，每次重建是一次纯函数推导。
> 系统状态完全由 Git 中的声明决定，机器是声明的投影。
