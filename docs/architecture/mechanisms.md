# 核心机制 — 十一层内幕

> 本文是 README「核心机制」节的深度版（T13.1 分层重构时从 README 原样迁出）。
> 每层一段：共享层两阶段初始化 / 策略生成 / 目标工厂 / pdshell / SOPS 安全 /
> orc 编排 / 用户环境 / 外部配置仓 / 提交规范 / 多主机 / 按需服务。
> 概览表见 [README](../../README.md#核心机制)。

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
    ├─ orc-raw                   — configuration-orchestrator（arch-specific，runtime 解析）
    └─ pdshell-raw               — pipeline-driven dev shell manager

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
| `sound`           | `pipewire` · `none`（T10.1 策略轴——本地声音服务器；每行携带 `sound-server` 能力位与 `mixers` 工具带；债 #9 机械半部，控制台主机的翻转待真机裁决）                                                                                                                               |
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

**可用 devShells 速查表（25 个 shell 的组合内容与特性）保留在[README 开发环境速查](../../README.md#日常操作速查)——该表承载 docs-SSOT 计数锚点（`可用 devShells 速查（25 个，…`），单一副本防漂移；本节只讲机制。**

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
  本机       → key-install-host 合并进 ~/.config/sops/age/keys.txt
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
- 从 0 到部署的全流程引导（六 Phase）见[快速开始](../guides/quickstart.md)，
  按情景的逐步手册见[多情景手册](../secrets/scenarios.md)。

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

（另两个 `flake = false` 输入非配置仓库：`nmt` 是测试框架 mirror，见[README 测试体系](../../README.md#测试体系)。）

**CI 覆盖与职责边界**：这些仓库以 flake.lock 锁定 revision 被消费，本仓 CI
对它们的集成正确性已全覆盖——deep-eval 硬门禁求值 95 checks 强制 fetch 全部
输入（仓库消失/移动即失败）、nmt 平面物料化 home 激活（配置树实际写入）、
VM 平面真实启动含这些配置的系统；外部仓库的坏提交在 update-flake.yml 开出
的 PR 上即被拦截。各仓库自身的语言级 lint（stylua 等）归各仓库自己的 CI——
本仓是消费者而非所有者（裁决记录见[README 路线图](../../README.md#路线图)末节）。

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

`hosts/` 目录实现多主机分发，每台机器独立硬件事实 + 可选 `shared.nix` 覆盖（主机计数锚点在 [README 目录结构](../../README.md#目录结构)；实时清单 `nix eval .#api.hosts`）。

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
