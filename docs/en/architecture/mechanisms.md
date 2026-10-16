# Core Mechanisms — Inside the Eleven Layers

> English mirror of [docs/architecture/mechanisms.md](../../architecture/mechanisms.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> This document is the deep-dive edition of the README's "Core Mechanisms" section (migrated verbatim out of the README during the T13.1 layered refactor).
> One section per layer: shared-layer two-stage initialization / policy generation / the target factory / pdshell / SOPS security /
> orc orchestration / user environments / external config repos / commit conventions / multi-host / on-demand services.
> For the overview table see the [README](../../../README.en.md#core-mechanisms).

### 1. Shared Layer — Two-Stage Initialization

`lib/shared` solves the circular "configuration depends on pkgs, pkgs depends on configuration" problem in Nix:

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

**Merge order (later entries override earlier ones):**

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

`lib/shared/default.nix` accepts an optional parameter `scfpath` (default `../../shared.nix`), allowing it to point at a different policy file in tests or multi-machine scenarios:

```nix
# 默认用法（flake.nix 中）
shared = import ./lib/shared { inherit self nixpkgs nixpkgs-unstable inputs; };

# 自定义策略文件路径（多机器场景）
shared = import ./lib/shared {
  inherit self nixpkgs nixpkgs-unstable inputs;
  scfpath = ./machines/server.nix;
};
```

After `runtime/default.nix` composes it, `fullShared` contains the following runtime fields:

| Field                          | Source                 | Description                                                        |
| ------------------------------ | ---------------------- | ------------------------------------------------------------------ |
| `caps`                         | runtime-resolved       | Platform capability vector (`caps.nixos-system` etc.) — **the single resolution point for platform semantics** |
| `pkgs`                         | runtime-injected       | Stable-channel nixpkgs (with overlays + config)                    |
| `upkgs`                        | runtime-injected       | Unstable nixpkgs (a second nixpkgs instance, not an overlay)       |
| `i18nScope`                    | runtime-resolved       | Scope of the i18n input-method packages (stable/unstable table-driven; mixed dual-source installs fail loudly here) |
| `homeDir`                      | runtime-computed       | Platform-aware home directory (Linux: `/home/<u>`, macOS: `/Users/<u>`) |
| `orc`                          | runtime-injected       | configuration-orchestrator lib (arch-resolved; wallust theme injection) |
| `pdshell`                      | runtime-injected       | pdshell, the pipeline-driven dev-environment builder               |
| `pdshells` / `mk-pdshell`      | runtime-injected       | pdshell function aliases                                           |
| `editors` / `terminals` / `browsers` | set-enum flattening | The selected-leaf lists of editor-set/terminal-set/browser-set (used for leaf routing) |
| `appCategories`               | set-enum flattening    | app-set's directory list (the map-routing key of `home/core/exp/app`) |
| `services`                     | set-enum flattening    | service-profile's `{db,virt}.{install,autostart}` matrix           |
| `shellIntegrations`            | enum payload           | Shell integration truth table (reused by the 8 base modules)       |
| `sopsFile`                     | runtime-injected       | `rel → store path`; derives the encrypted-file path from a secret REL |
| `sopsPath`                     | runtime-injected       | `rel → /run/secrets/<rel>`; runtime path of an ordinary secret     |
| `sopsUserPath`                 | runtime-injected       | `rel → /run/secrets-for-users/<rel>`; path of a neededForUsers secret |
| `provenance`                   | runtime-computed       | Dual-channel nixpkgs fingerprint (`pkgsFingerprint`; eval-time logging and auditing) |
| `_user_shared`                 | runtime-retained       | Raw user_shared snapshot (for debugging/introspection)             |
| `packages`                     | runtime-injected       | The set of custom derivations imported from the `pkgs` directory   |
| `overlays`                     | runtime-injected       | The overlays imported from the `overlays` directory (patches included) |

**Utility functions (`shared.fn`, all pure):**

```nix
shared.fn.homeDir  shared.platform shared.user.username   # → "/home/kilig" 或 "/Users/kilig"
shared.fn.sopsBase shared.self shared.const.secrets.chipr # → chipr 目录的 store 路径
shared.fn.sopsFile shared.self shared.const.secrets.chipr "nixos/core/base/user/kilig/password"
shared.fn.sopsRuntimePath shared.const.secrets.forUsersPath "nixos/core/base/user/kilig/password"
shared.fn.pkgsFingerprint pkgs                            # → nixpkgs 版本指纹
shared.fn.sameSource pkgA pkgB shared.i18n.nixpkgs-source # → eval 期双源守卫（995d8c9 事故的
                                                          #    结构性免疫：stable/unstable 混装在此 throw）
```

**System constants (`shared.const`):**

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

**Unified tool-library management (`shared.tools`)** — external tool libraries are registered centrally, and config files reach them through short paths, decoupling direct references to `inputs.<long-name>.lib`:

```
lib/shared/lang/tools.nix
    ├─ nix-types（短别名 nt）    — ADT 系统：enum / match / Option / Result
    ├─ orc-raw                   — configuration-orchestrator（arch-specific，runtime 解析）
    └─ pdshell-raw               — pipeline-driven dev shell manager

配置文件消费方式：
    shared.tools.nix-types.match shared.version { ... }     # 替代 inputs.nix-types.lib.match
    shared.orc.mergeHomeFiles ...                           # runtime 已按 arch 解析
```

`shared` is then passed as `specialArgs`/`extraSpecialArgs` to all NixOS/Home Manager modules, which consume it through `{ shared, ... }`.

**`api.*` — a script-queryable flake-side index:**

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
# → { "home": 42, "integration": 1, "lib": 5, "nixos": 29, "nmt": 15, "smoke": 1 }
```

### 2. Policy Layer — The shared.nix Generation Mechanism

`shared.nix` is the single source of truth of the entire system; every platform-related decision is centralized here.

**Generate, Don't Mutate**

```
docs/tmpl/shared.nix.tmpl   手动维护，含 __USERNAME__ 占位符（提交 Git）
    ↓  just shared-generate <username>   (sed 替换 → 覆盖写入)
shared.nix                  生成产物，覆盖写入，不可 sed patch（提交 Git）
    ↓  lib/shared/default.nix: 两阶段初始化 + hosts/<h>/shared.nix 浅 // 合并
fullShared                  运行时合成（lang + user_shared + runtime）
    ↓  specialArgs / extraSpecialArgs
platform/ · home/           通过 { shared, ... } 消费
```

**Host policy overrides (wholesale semantics):** `hosts/<h>/shared.nix` is a **shallow wholesale replacement** of the base record — top-level keys are swapped out whole and never deep-merged (enum instances are attrsets; a deep merge would corrode the policy payload). After merging, the result passes schema re-validation, and `hostName` is force-aligned to the directory name by the loader (loading from hosts/foo while routing to bar is impossible). The base host (nixos) has no override file — the base record itself is its policy.

**Configurable enums (lib/shared/lang/enum.nix):**

| Field             | Legal values                                                                                                                                                                                                                                                                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `arch`            | `x86_64-linux` · `aarch64-linux` · `x86_64-darwin` · `aarch64-darwin` · `i686-linux`                                                                                                                                                                                                                                                           |
| `platform`        | `nixos` · `linux` · `darwin` · `wsl` · `nixos-wsl` (each row carries the `caps` capability vector and a policy payload)                                                                                                                                                                                                                         |
| `window-manager`  | `hyprland` · `niri` · `gnome` · `none` (Null-Object; each value carries a `portal` policy)                                                                                                                                                                                                                                                      |
| `display-manager` | `ly` · `gdm` · `sddm` · `lemurs` · `none` (T7.1 Null-Object row — the console form)                                                                                                                                                                                                                                                            |
| `sound`           | `pipewire` · `none` (T10.1 policy axis — the local sound server; each row carries a `sound-server` capability bit and a `mixers` tool belt; debt #9's mechanical half has landed, and its semantic half is pre-adjudicated to `none` with the flip row pre-staged — case file: [sound-adjudication.md](../guides/sound-adjudication.md), evidence gathered via `just sound-audit`, T17.1) |
| `drive-group`     | `intel` · `amd` · `nvidia` · `nvidia-prime` · `amd-nvidia` · `amd-nvidia-prime` · `intel-nvidia` · `intel-nvidia-prime`                                                                                                                                                                                                                          |
| `shell`           | `zsh` · `fish` · `bash` (each row carries the `integrations` truth table)                                                                                                                                                                                                                                                                       |
| `editor`          | `nvim` · `vim` · `code` · `zeditor`                                                                                                                                                                                                                                                                                                            |
| `editor-set`      | `minimal` · `full-ai` · `dev` · `full` (multi-select routing; carries the `editors` list)                                                                                                                                                                                                                                                       |
| `terminal-set`    | `kitty-only` · `wezterm-only` · `both` (multi-select routing; carries the `terminals` list)                                                                                                                                                                                                                                                      |
| `browser-set`     | `chrome-only` · `qutebrowser` · `cli-only` · `chrome-qute` · `all` (multi-select routing; carries the `browsers` list)                                                                                                                                                                                                                           |
| `app-set`         | `full` · `lean` · `none` (directory-level routing, T5.10 lazy module loading: carries the `categories` list — which app trees the host merges; the browser/editor/terminal trio of directories is reached on every row (they prune themselves via their own sets); the order of the `full` row is the module merge order — the closure-hash fingerprint anchor, locked by the enum tests) |
| `service-profile` | `full-autostart` · `dev-on-demand` · `server-pg-only` · `minimal` (carried as policy; controls db/virt install vs autostart)                                                                                                                                                                                                                   |
| `pointer-cursor`  | 12 Bibata variants, e.g. `Bibata-Modern-Amber`                                                                                                                                                                                                                                                                                                 |
| `version`         | `v25_11` (carries `{stateVersion, wine, swww, adb}` policies) · `v26_05` (isomorphic)                                                                                                                                                                                                                                                            |

`window-manager` enum values embed a `portal` policy that `platform/nixos/system/core/base/portal.nix` and `home/core/base/portal.nix` consume directly:

```nix
# enum.nix 中的结构
hyprland = { portal = { default = [ "hyprland" "gtk" ]; extraPortals = (pkgs: ...); wlr = false; }; };
niri     = { portal = { default = [ "wlr" "gtk" ];      extraPortals = (pkgs: ...); wlr = true;  }; };
gnome    = { portal = { default = [ "gtk" ];            extraPortals = (pkgs: ...); wlr = false; }; };

# 消费侧（portal.nix）
xdg.portal.extraPortals = shared.window-manager.portal.extraPortals pkgs;
xdg.portal.config.common.default = shared.window-manager.portal.default;
```

**Platform capability table (T4.0 distribution-layer convergence) — `enum.platform` is the target description:**

```nix
# lib/shared/lang/enum.nix：每行回答"该平台是什么"，一处声明
nixos = { caps = { linux-family = true; nixos-system = true; wsl = false; darwin = false;
                    system-nix = true; };  # 第 30 轮新增列：系统级 nix 平面是否存在——
          # home/core/base/nix.nix 读其否定作能力声明（无系统平面的 standalone 形态，
          # 用户级 ~/.config/nix/nix.conf 是舰队唯一可达平面；有系统平面则保持沉默
          # ——nix.conf 优先级链：用户文件会按设置遮蔽系统文件，不可双平面）
          home-prefix = "/home"; btop = pkgs: pkgs.btop.override { … }; … };

# lib/shared/targets.nix 输出路由读同一张表（faces.nix 只消费成品；
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

Adding a platform = writing one row; adding a capability dimension = adding one column (exhaustive by construction, like an nix-types match).
The contract test `tests/lib/shared/lang/caps.nix` locks the entire table (truth table + policy selection + exhaustiveness).

### 3. Distribution Layer — The targets.nix Target Factory

`lib/shared/targets.nix` is the production side of target construction — a compiler-shaped backend pass. A three-stage pipeline:

```
前端     hostNames = readDir ../../hosts（仅目录）
             ↓ 加机器 = mkdir hosts/<name>，零 flake.nix 改动
中间端   caps 分类（查能力表，永不重词法分析目标）：
             nixosHosts      = caps.nixos-system
             darwinHosts     = caps.darwin
             standaloneHosts = !caps.darwin（darwin standalone 会携带 linux pkgs——结构性排除）
后端     三类发射器（统一目录引用，语法 v3）：
             mkNixosSystem  → modules = [ ../../platform/${tag}/system ] （grammar v4：域地址显式）
             mkDarwinSystem → modules = [ ../../platform/${tag}/system ] （system = arch.tag 参数吸收）
             mkHomeSystem   → modules = [ ../../platform/${tag}/home ]    （门即 payload，arch 退役）
```

**Single instantiation of the policy IR (T5.10, distribution-layer CSE):** `sharedByHost = genAttrs hostNames mkShared` is the one table, and the classifier/emitters/naming/aliases all read that table; the default host's table entry = the base instance (handle sharing — the default host never pays twice for the same IR). The base `shared` of the link pass (faces.nix, R31) consumes `targets.base` (the backend exports the already-built base-IR handle) instead of importing a second time. Legacy aliases `<user>-<platform>` are attr-level thunk aliases (sharing the same closure, not a re-emission).

**Finished products (faces.nix writes only inherit; flake.nix is down to registration + a one-line delegation, R31):**

```nix
inherit (targets) nixosConfigurations;   # 每台 nixos 主机 + legacy 别名
inherit (targets) homeConfigurations;    # "<user>@<host>"（kilig@nixos · kilig@vm · kilig@wsl）
inherit (targets) darwinConfigurations;  # 每台 darwin 主机（darwin）
inherit (targets) colmenaHive;           # 部署面（colmena 0.5+）
inherit (targets) hostToplevels;         # api.host-toplevels 的 Linux toplevel 投影（R31）
inherit (targets) darwinToplevels;       # api.darwin-toplevels 的 darwin toplevel 投影（R31）
```

### 4. Dev-Environment Pipeline — pdshell

Dev environments are driven by the external flake [`pdshell`](https://github.com/Redskaber/pdshell), which implements pipeline-style shell construction:

```
组合定义 (combinFrom)
    → 策略解析 (per-lang config: buildInputs · nativeBuildInputs · hooks)
    → 输入合并 (buildInputs ∪ nativeBuildInputs)
    → 钩子组合 (preInputsHook · postInputsHook · preShellHook · postShellHook)
    → 验证
    → mkShell 输出 → devShells.${system}
```

**Lifecycle hooks:**

| Hook              | Timing                                          | Typical use                                               |
| ----------------- | ----------------------------------------------- | --------------------------------------------------------- |
| `preInputsHook`   | Before dependency injection                     | Environment checks, precondition validation               |
| `postInputsHook`  | After dependency injection, before shell startup | Export environment variables (CC/CXX/GOPROXY etc.)        |
| `preShellHook`    | On entering the shell (first)                   | Entry animation, welcome preamble                         |
| `postShellHook`   | On entering the shell (last)                    | Welcome message, usage hints, alias registration          |

**Composite environments (combinFrom):**

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

**The quick-reference table of available devShells (the compositional contents and traits of all 25 shells) stays in the [README's dev-environment quick reference](../../../README.en.md#daily-operations-quick-reference) — that table carries the docs-SSOT count anchor (`可用 devShells 速查（25 个，…`), a single copy to prevent drift; this section covers the mechanism only.**

**Consumption contract (T31, test #101 `lib_shared_pdshell`):** the loader is itself one of the consumed tool libraries — test #101 drives the production handle `shared.pdshells` × the same arguments flake.nix passes, asserting five groups against the real tree: **census** (the exact 25-member set — membership; the only tripwire against `_`-prefixed silent exclusion and upstream fn-makeFullName naming drift), **face** (`dev-shell-<member>` name injection), **combinFrom** (the root default's own buildInputs is `[]`; all 117 merged inputs must arrive via the contributions of the fourteen language defaults — four probes, one language each), **lifecycle** (the `# ===` section markers + inherited-before-own ordering + FINAL SHELL OVERRIDE exporting the identity-axis shell), and **NamedFile isolation** (renpy ships its own engine and leaks no sibling or cross-scope inputs). The census anchor MEMBERSHIP and the docs-ssot anchor COUNT complement each other — the two must travel in the same commit.

### 5. Security Layer — SOPS + Age (Layered Management)

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

**Key-tier state machine (to bootstrap is to migrate):**

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

**On repository state and the factory-fresh state:** this repository ships the maintainer's own `.sops.yaml` (public keys) and `secrets/chipr/**` (ciphertext encrypted under the maintainer's key) — they are **undecryptable by you**, and there is no need to delete them. The bootstrap experience for forkers/adopters is identical to the factory-fresh state: after regenerating the policy with `just shared-generate <your-username>`, `secrets-destroy-all` (wipes the maintainer's ciphertext) → `secrets-init` → `secret-set-all` (encrypted under your key, then committed) completes the takeover. Eval is lenient toward the no-blob state (the resolution pass of `lib/shared/lang/validate.nix` merely traces bootstrap commands); once a blob appears on the tree, it turns strict — a secret that is declared but missing is reported at eval time as "declared but not provided". deploy hard-fails during sops activation in the keyless state (the correct failure layer).

- **The user domain** (`core/base/{user,nix}`) → user key only; **the srv domain** (`core/srv/`) → host + user dual keys (see `docs/secrets/rotation.md` for details).
- Lifecycle operations surface: `just secrets-guide` (the map) / `just secrets-status` (audit) / `just secrets-list` (alias table × status) / the full verb table is in rotation.md §4 (create / update / destroy × key / rules / blob).
- The full zero-to-deploy bootstrap (six phases) is in [Quick Start](../guides/quickstart.md); step-by-step, per-scenario walkthroughs are in the [Multi-Scenario Handbook](../secrets/scenarios.md).

**Secret permission matrix:**

| Secret                         | mode   | owner    | group       | path prefix              |
| ------------------------------ | ------ | -------- | ----------- | ------------------------ |
| `user.password`                | `0400` | root     | root        | `/run/secrets-for-users` |
| `nix.user.github.access-token` | `0400` | \<user\> | \<user\>    | `/run/secrets`           |
| `mongodb.user.password`        | `0400` | mongodb  | mongodb     | `/run/secrets`           |
| `mysql.root.password`          | `0400` | root     | root        | `/run/secrets`           |
| `mysql.user.password`          | `0440` | root     | mysql       | `/run/secrets`           |
| `postgresql.user.password`     | `0440` | root     | postgres    | `/run/secrets`           |
| `redis.user.password`          | `0440` | root     | redis-\<u\> | `/run/secrets`           |

**Data-driven design (zero hardcoded paths):** every secret path in `secrets.just` is read from `shared.nix` at runtime; the alias mapping lives in exactly one registry:

- `_secrets-mkdir` — walks every `nixos.*` secret value, `dirname(REL)` → `mkdir -p`
- `_secrets-plan-gen` — only the dotted key is needed; path/template are both derived automatically
- `_secrets-encrypt` — the single universal encrypt-writer; awk ENVIRON-safe substitution (so characters like `|` and `\` inside passwords cannot break sed), atomic writes (mktemp + mv)

**Single template derivation rule:**

```
REL      = shared.nix 中 dotted key 对应的路径值
TMPL_REL = REL | sed "s|/${U}/|/__USERNAME__/|g; s|redis-${U}|redis-__USERNAME__|g"
TMPL     = SECRETS_TMPL_PATH / TMPL_REL + ".yaml"
```

**`.gitignore` requirement:**

```gitignore
# plaintext secret instances — NEVER commit
secrets/plan/
```

**Single source of information:** every stage reads the username from `shared.nix`.

| Stage           | Information source | Precondition                         | Command set                                                    |
| --------------- | ------------------ | ------------------------------------ | --------------------------------------------------------------- |
| BOOTSTRAP       | `shared.nix`       | `just shared-generate` has been run  | `secrets-init`, `key-new-host`, `key-add-host`                  |
| POST-BOOTSTRAP  | `shared.nix`       | `just shared-generate` has been run  | `secret-set`, `secret-get`, `secret-edit`, `secrets-list`       |
| LIFECYCLE       | `.sops.yaml`       | bootstrap has been completed         | `secrets-sync`, `key-rotate-*`, `key-remove`, `secret-remove`   |

### 6. Configuration Orchestrator — orc (ConfigurationOrchestrator)

`shared.orc` is an operations library over a purely generic config lib, providing capabilities such as filtering and editing of configs; for example, the wallust dynamic theme-injection mechanism, used during the Home Manager activation stage to copy dynamically generated color-scheme files (wallust output etc.) into the corresponding config directories:

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

**The include-intent guard (a consumption-face fact):** `mergeHomeFiles` **fails fast at eval time** on policies whose include is non-empty yet matches nothing (orc 05c658f; `allowEmpty = true` is the explicit opt-out) — include rot (an upstream file move/rename/typo) no longer yields a silently empty activation but an eval-time explosion carrying the include patterns + FileMap keys + four-way reconciliation guidance. The fleet consumes this guard through flake.lock, and `tests/lib/shared/orc-guard.nix` (test #100) uses the production handle `shared.orc` × the real swaync-config tree to pin that capability in place within the locked orc.

### 7. User-Environment Layer — home/env

`home/env` is a global runtime environment layer independent of `home/core`, imported alongside `home/core` inside the user-domain gate of every platform (`platform/<platform>/home/default.nix`, grammar v4 — the gate is the payload; the arch axis is retired):

```
platform/<platform>/home/default.nix
    imports = [ ../../../home/core  ../../../home/env  ../../../home/wm ]
```

**Sub-layer responsibilities:**

| Sub-layer  | Path             | Description                                                                                                                                              |
| ---------- | ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `env/base` | `home/env/base/` | Global base packages: compilers (clang/rustc/cargo), runtimes (python314/nodejs_26), debugging tools (valgrind/strace/ltrace), hardware tools (pciutils/vulkan-tools) |
| `env/dev`  | `home/env/dev/`  | pdshell devShell definition files (one directory per language, loaded by the `devShells` output of `flake.nix`; **not an HM module tree**)                  |

**`sys/ai/` — the AI CLI sub-layer:**

`home/core/exp/sys/ai/` is an AI-tool sub-layer independent of `sys/base/`, imported only inside `home/core/exp/sys/`; it contains:

| Tool               | Package            | Description                      |
| ------------------ | ------------------ | -------------------------------- |
| `claude-code`      | `claude-code`      | Anthropic Claude CLI (code)     |
| `opencode`         | `opencode`         | Open-source AI coding assistant |
| `gemini-cli`       | `gemini-cli`       | Google Gemini CLI               |
| `kiro-cli`         | `kiro-cli`         | AWS Kiro CLI                    |
| `cursor-cli`       | `cursor-cli`       | Cursor AI editor CLI            |
| `pi-coding-agent`  | `pi-coding-agent`  | pi coding agent                 |

What `env/base` provides are global tools that are **always available**, with no devShell activation required. The definitions in `env/dev` take effect only under `nix develop` or `just devenv-*`.

**devShell definition convention (env/dev/<lang>/default.nix):**

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

The `combinFrom` field is handled by the pdshell engine, which merges the `buildInputs`, `nativeBuildInputs`, and all hooks of several language environments into a single `mkShell`.

### 8. External Config Repositories (flake=false inputs)

All tool configs are brought in as standalone Git repositories (24 `flake = false` inputs, of which 22 are dotfile config repos), written into `~/.config/<app>/` by Home Manager at activation:

| flake input            | Target path                                                                     |
| ---------------------- | ------------------------------------------------------------------------------- |
| `nvim-config`          | `~/.config/nvim/`                                                               |
| `emacs-config`         | `~/.config/emacs/`                                                              |
| `vscode-config`        | `~/.config/Code/User/`                                                          |
| `starship-config`      | `~/.config/starship.toml`                                                       |
| `fastfetch-config`     | `~/.config/fastfetch/`                                                          |
| `wezterm-config`       | `~/.config/wezterm/`                                                            |
| `kitty-config`         | `~/.config/kitty/`                                                              |
| `tmux-config`          | `~/.config/tmux/`                                                               |
| `mpv-config`           | `~/.config/mpv/`                                                                |
| `btop-config`          | `~/.config/btop/`                                                               |
| `cava-config`          | `~/.config/cava/`                                                               |
| `hypr-config`          | `~/.config/hypr/`                                                               |
| `niri-config`          | `~/.config/niri/`                                                               |
| `rofi-config`          | `~/.config/rofi/`                                                               |
| `swaync-config`        | `~/.config/swaync/`                                                             |
| `wallust-config`       | `~/.config/wallust/`                                                            |
| `waybar-config`        | `~/.config/waybar/`                                                             |
| `wlogout-config`       | `~/.config/wlogout/`                                                            |
| `quickshell-config`    | `~/.config/quickshell/`                                                         |
| `qutebrowser-config`   | `~/.config/qutebrowser/`                                                        |
| `fcitx5-config`        | `~/.config/fcitx5/`                                                            |
| `input-overlay-config` | `~/.config/obs-studio/plugin_config/input-overlay/`                             |
| `commit-config`        | `<project>/.cz.toml`, `<project>/commitlint.config.js`, `<project>/.husky/`      |

(The two remaining `flake = false` inputs are not config repos: `nmt` is the test-framework mirror — see the [README's Test System](../../../README.en.md#test-system).)

**CI coverage and the responsibility boundary:** these repos are consumed at the revisions locked by flake.lock, and this repo's CI already covers their integration correctness in full — the deep-eval hard gate (T15.1 face-sharded form) forces per-host toplevel evaluation of nixosConfigurations (a repo vanishing/moving fails immediately), the five vm-tests planes materialize at build level the systems that contain these configs (evaluation + build both passing — stronger), and output-faces forces the packages/home/darwin faces; a bad commit in an external repo is intercepted right on the PR opened by update-flake.yml. Each repo's own language-level lint (stylua etc.) belongs to that repo's own CI — this repo is a consumer, not an owner (the adjudication record is in the final section of the [README's Roadmap](../../../README.en.md#roadmap)).

### 9. Commit Conventions — Husky + Commitlint + Commitizen (Zero node_modules)

Commit conventions are likewise brought in as the external config repo `commit-config` (`flake = false`), deployed in a data-driven way through `scripts/just/commit.just`, **with no `node_modules` whatsoever**. Main components:

- **Global tools** (installed by Home Manager via `home.packages`): `commitlint`, `husky`, `commitizen`.
- **Rules and interactive config**: `commitlint.config.js` (defines the allowed commit types) and `.cz.toml` (used by `cz commit`; the types align exactly with commitlint).
- **Git hooks**: `husky/commit-msg` invokes the global `commitlint` command directly, validating the message format on every commit.

**Rapid deployment (works for any Git repository):**

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

All commands dynamically fetch `commit-config`'s path in the Nix store from `flake.nix`'s `api.inputs`, ensuring full reproducibility. When the rules change, update the `commit-config` repo and simply re-run `just commit-setup` to sync.

### 10. Multi-Host Support — hosts/

The `hosts/` directory implements multi-host distribution: each machine gets independent hardware facts + an optional `shared.nix` override (the host-count anchor lives in the [README's Directory Structure](../../../README.en.md#directory-structure); the live inventory is `nix eval .#api.hosts`).

**The three files of machine facts (T5.12 + T5.13 + T5.14 — the data + interpreter route):**

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

The legacy form: hardware.nix is a **generated NixOS module** — after nixos-generate-config probes the hardware, fileSystems, initrd modules, and microcode are all hardcoded into the artifact as option assignments. The declarative form splits files by fact type: **facter.json is hardware data** (a standard facter report schema, version 1), interpreted by the `hardware.facter` module that comes with nixpkgs (inside the default module set) — the initrd virtio module set, `nixpkgs.hostPlatform` (report.system), and guest handling (virtualisation → the qemu-family module set) are all derived from the report; **disk.nix is disk data** (a disko.devices layout declaration: partition table, partition roles, filesystems and mount points), interpreted by the disko module — `fileSystems`, `swapDevices`, and the BIOS boot `boot.loader.grub.devices` are all derived from the layout. The differing interpreter registration locations are the direct consequence of the upstreaming difference: the facter module has been upstreamed into nixpkgs (zero imports, zero inputs); disko is not in nixpkgs (verified against the locked tree), so its registration = a one-line import in `platform/nixos/system/core/base/disk.nix` — **capability belongs to the platform structure tree, data belongs to hosts/** (the same adjudication as sops-nix being registered in core/sec/secret); **persist.nix is state-policy data** (the machine fact that "the root is ephemeral" + the environment.persistence manifest of what survives), interpreted by the impermanence module + the rollback mechanism (likewise not in nixpkgs — verified against the locked tree; registration = `platform/nixos/system/core/base/impermanence.nix`). The three fact pairs share one adjudication chain. The value of separating data from interpreter is isomorphic to hosts/ itself: machine facts are frontend data, the capability that interprets them is the backend, and the host entry point does a single line of wiring.

Real-machine migration (run on the target machine; the disk layout is a reinstall-time concern — applying disko repartitions the disk, so data cannot be preserved):

```
  0. just hardware-migrate   # T19.1 一键路径：下面 1-3 步的自动化（探测报告 +
                             #   挂载/kernelModules 原样搬入主机入口 + 接线翻转 +
                             #   legacy 退役；终态由 lib_shared_targets 普查锁定）
  1. just hardware-facter    # 生成 hosts/<hostname>/facter.json（root 扫描）
  2. 主机入口：imports = [ ./hardware.nix ] → hardware.facter.reportPath = ./facter.json;
  3. 删除 hardware.nix 中的 initrd/hostPlatform 行；fileSystems 走第 4 步
  4. 写 hosts/<hostname>/disk.nix（声明目标分区表）+ 主机入口 imports ./disk.nix；
     重装时从 installer 运行 just disk-format <hostname>（分区/格式化/挂载，破坏性）
  5. 可选（实验路线）：btrfs 布局 + hosts/<hostname>/persist.nix 声明 ephemeral root
     （enable + 生存清单）+ imports ./persist.nix——参考 hosts/vm 三件套
```

The vm's report is a **declaration**, not a probe artifact — a VM's hardware is defined by construction (QEMU x86_64 guest + virtio disk/NIC), so the report simply writes that shape down in the standard schema (kvm virtualization, virtio_blk/virtio_net driver_modules, vCPUs without vmx/svm). The report deliberately omits network_interface: the platform's NetworkManager policy owns DHCP, while facter's per-interface useDHCP defaults to scripted networking and would layer dhcpcd underneath NM; CONTROLLER (virtio-net) is in the report, and its driver still enters the initrd. By the same token, vm's disk layout is also a declaration: GPT + EF02 (BIOS boot, the 1 MiB staging for grub's core.img) + a root btrfs filling the rest of the disk, four subvolumes in four lifetimes (T5.14): `root` mounted at / (ephemeral — archived to old_roots/<timestamp> by the rollback mechanism at every boot and rebuilt empty), `persistent` at /persistent (state), `nix` at /nix (store-closure survival), `boot` at /boot (the boot chain — the kernel and grub.cfg must never evaporate with the root). The EF02 partition in the layout is precisely the basis from which disko derives `boot.loader.grub.devices = ["/dev/vda"]` (the structured expression of the BIOS form), cross-confirming the facter report's `uefi: false`; the host file only fills in the boot-policy alignment (grub on / systemd-boot off — the platform default targets the UEFI machine fleet).

**Ephemeral root (a T5.14 experiment, vm only):** `just persist-show vm` reads out the entire state contract. The rollback mechanism is the platform-side interpreter (`platform/nixos/system/core/base/impermanence.nix`): it reads the root-mount facts already declared in the layout (device/fsType/subvol — the disko _config output) and derives the upstream authoritative recipe (the BTRFS subvolumes section of impermanence's README.org): archive the old root → delete old roots older than retain-days (default 30 days) → rebuild an empty subvolume → only then mount /. **Two initrd modes, one recipe**: systemd stage 1 (the platform fleet default) lands as a oneshot before sysroot.mount (the gate sits on the root-device unit — a systemd-repart precedent); classic stage 1 lands as postResumeCommands (executed before the root-mount loop — an upstream hook). btrfs-progs entering the initrd is not hand wiring: NixOS's btrfs task module derives it from the fileSystems fsType. Upstream already asserts that "every persistence path must be neededForBoot"; the interpreter satisfies this with mkDefault. This repo is one notch stricter: every persistence path must be a declared mount (a layout gap → fails loudly at eval time).

platform/nixos/system/default.nix dynamically routes to the corresponding host through ../../../hosts/${shared.hostName} (the system boundary mounts the host facts; darwin's boundary works the same way). **Consumption asymmetry:** `hosts/<h>/default.nix` is imported only by the system boundary; `hosts/<h>/shared.nix` is consumed by the policy loader of every closure class — the standalone HM path never touches host system facts. Adding a new host takes only:

```
  1. mkdir hosts/<new-hostname>
  2. just hardware-facter    # 写入 hosts/<hostname>/facter.json（或 hardware-generate 走 legacy）
  3. 写 hosts/<new-hostname>/shared.nix（策略覆盖；基主机无此文件）
```

### 11. On-Demand Service Startup — service-profile

NixOS service management has 3 layers:

| Layer               | Mechanism                           | Persistence                          | Who controls it             |
| ------------------- | ----------------------------------- | ------------------------------------ | ---------------------------- |
| **Install**         | `enable = true`                     | Persists after a rebuild             | nix config                   |
| **First autostart** | `wantedBy = ["multi-user.target"]` | Re-applied after a rebuild           | nix config (service-profile) |
| **Boot autostart**  | `systemctl enable/disable`          | Persistent across reboots + rebuilds | Manual, by the user          |

The `service-profile` enum controls **installation** and the **first autostart**:

```nix
# shared.nix
service-profile = shared.enum.service-profile.dev-on-demand;

# dev-on-demand profile:
#   db.postgresql  = { install = true;  autostart = false; }  # 装但不自启
#   db.mongodb     = { install = false; autostart = false; }  # 不装
#   virt.podman    = { install = true;  autostart = true;  }  # 装且自启

# 配置文件消费（platform/nixos/system/core/srv/db/postgresql.nix）
services.postgresql.enable = shared.services.db.postgresql.install;
systemd.services.postgresql.wantedBy =
  lib.mkForce (lib.optional shared.services.db.postgresql.autostart "multi-user.target");
```

**Key design:** `dev-on-demand` sets `wantedBy = []`, which means NixOS **does not manage boot-autostart symlinks through nix**. The user manages them via `systemctl`:

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

**Core principles:**

- nix files decide only "install" and "whether it autostarts the first time after a build"
- once that first decision has been made, service state is managed entirely by the user through `systemctl`
- **no need to modify nix files + rebuild to change a service's running state**
- `systemctl enable/disable` state persists across reboots and across rebuilds

Optional profiles: `full-autostart` / `dev-on-demand` / `server-pg-only` / `minimal`

---
