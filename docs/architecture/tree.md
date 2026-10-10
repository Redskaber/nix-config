# 目录结构 — 完整注释树

> 本文是 README「目录结构」节的深度版（T13.1 分层重构时从 README 原样迁出）。
> 速览版（三级目录 + 规模事实）见 [README](../../README.md#目录结构)。

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
│   │                       #   genericLinux + systemd；无系统形态，顶层无 default.nix；
│   │                       #   整个平台目录即用户域；WSL 用户空间 interop 由共享树
│   │                       #   home/core/base/wsl.nix 按 caps.wsl 提供，T7.1）
│   └── nixos-wsl/          # NixOS-WSL 第五形态（T7.1）：default.nix = 薄门——
│                           #   ../nixos 复用 + NixOS-WSL 解释器；home/ = 用户域
│                           #   （payload 行回用 nixos 用户域行；门即形态定义）
│
├── home/                   # 用户层（Home Manager）—— 无根入口，仅由 payload 行导入
│   ├── core/
│   │   ├── base/           # 基础：字体 · i18n(fcitx5) · portal(wm 策略驱动) · XDG
│   │   │                   #   · wsl（caps.wsl 门控的 WSL 用户空间 interop：wslview/WSLENV，T7.1）
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
│   ├── nixos-wsl/         # NixOS-WSL 主机（T7.1）：shared.nix（platform=nixos-wsl
│   │                      #   第五行翻转 + dm/wm none + lean 集）+ default.nix（唯一机器
│   │                      #   事实 = arch——无 facter/disk/persist，见文件头）
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
├── tests/                  # 测试层（6 平面，93 tests + 2 仓库卫生 checks = 95 checks）
│   ├── default.nix         # 统一注册表：Plane 0–5 全部 checks（nixosTest runner）
│   ├── test_calc.nix       # Plane 0: Smoke 基线
│   ├── nixos/              # Plane 1: NixOS-Plane（QEMU VM，30 tests）
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
│   ├── architecture/       # 深度架构：mechanisms.md（十一层机制）· tree.md（本文件）
│   │                       #   · dependency-graph.md（T13.1 分层重构迁出）
│   ├── ci/                 # pipeline.md（CI/CD 深度手册：预检/部署/世代/自动化）
│   ├── guides/             # quickstart.md（六 Phase 全程）· extending.md（扩展指南）
│   ├── just/               # reference.md（82 recipe × 13 组全参考）
│   ├── preview/            # 截图预览
│   ├── modules/            # export/ 模块接口规范（interface-standards.md）
│   ├── secrets/            # rotation.md（轮换 runbook）· scenarios.md（九情景手册）
│   ├── tests/              # 测试文档：test-matrix.md · nixosTest.md · nmt.md
│   └── tmpl/
│       ├── shared.nix.tmpl # 策略层模板（__USERNAME__ 占位符；提交到 Git）
│       └── sops/           # SOPS secret YAML 模板（镜像路径层级结构）
│           ├── sops-rules.yaml.tmpl
│           └── nixos/      # 模板 YAML 文件（__USERNAME__ / __SECRET_VALUE__ 占位符）
│
├── .github/
│   └── workflows/
│       ├── ci.yml          # 9 阶段 CI 流水线（lint → deep-eval → nmt → devshells
│       │                   #   → output-faces → security → vm-tests →
│       │                   #   host-toplevels → summary）
│       └── update-flake.yml# 每周日自动更新 flake inputs 并开 PR
│
└── justfile                # 任务自动化入口（ROOT 变量 + import 子模块 + 裸 just 地图）
```

---
