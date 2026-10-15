# NixOS Config — Test Matrix

> `docs/tests/test-matrix.md`
> Updated: 2026-10-10

---

## 目录

1. [架构概述](#1-架构概述)
2. [测试平面划分](#2-测试平面划分)
3. [完整测试矩阵](#3-完整测试矩阵)
4. [目录结构](#4-目录结构)
5. [运行指南](#5-运行指南)
6. [设计原则与约束](#6-设计原则与约束)
7. [扩展新测试](#7-扩展新测试)
8. [CI 集成](#8-ci-集成)

---

## 1. 架构概述

```
tests/
├── default.nix              ← 统一注册表: Plane 0–5 全部 checks
├── test_calc.nix            ← Smoke 基线
├── nixos/                   ← NixOS-Plane (QEMU VM)
├── home/                    ← HM-Plane   (QEMU VM + packages)
├── lib/                     ← Lib-Plane  (pure Nix eval, minimal QEMU)
├── integration/             ← Integration-Plane (NixOS + HM)
└── nmt/
    ├── default.nix          ← Plane 5 runner (buildHomeManagerTest impl)
    └── home/…               ← 测试文件 (lib.nmt.buildHomeManagerTest)
```

### nmt 获取机制与调用链

```
flake.nix
  nmt.url   = "github:Redskaber/nmt"   ← sourcehut mirror (flake = false)
  nmt.flake = false                     ← 无 flake.nix，原始 store path

tests/nmt/default.nix
  nmtSrc  = inputs.nmt                  ← store path
  hmPath  = inputs.home-manager         ← HM modules + stdlib-extended lib
  hmLib   = import "${hmPath}/modules/lib/stdlib-extended.nix" pkgs.lib
  hmModules = import "${hmPath}/modules/modules.nix" { lib; pkgs; check=false; }

  buildHomeManagerTest testSpec
    → import nmtSrc {
        lib            = hmLib;
        pkgs           = scrubbedPkgs;   ← derivations → "@pkg-name@"
        modules        = hmModules ++ [baseModule] ++ testSpec.modules;
        testedAttrPath = ["home" "activationPackage"];
        tests          = { <name> = { nmt.script = …; }; };
      }
    → result.build.<name>               ← derivation for flake check
```

### 为什么不用 sourcehut / fetchTarball

| 方案                                   | 结果                                  |
| -------------------------------------- | ------------------------------------- |
| `sourcehut:~rycee/nmt` flake input     | ❌ HTTP 403 — go-away bot-protection  |
| `fetchTarball "https://git.sr.ht/…"`   | ❌ HTTP 403 — 同一封锁策略            |
| `inputs.home-manager.lib.hm.nmt`       | ❌ release-25.11 不导出此属性         |
| `github:Redskaber/nmt` + `flake=false` | ✅ GitHub 可访问，store path 直接引用 |

### `buildHomeManagerTest` 不是 nmt 原生 API

nmt 的 `default.nix` 真实签名：

```nix
{ modules, testedAttrPath, tests, pkgs, lib ? pkgs.lib }
→ { build; run; report; list }
```

`buildHomeManagerTest` 是 home-manager 自己的测试包装器，**不存在于 nmt 本身**。
`tests/nmt/default.nix` 完整实现了这个 wrapper，使现有所有测试文件无需修改。

---

## 2. 测试平面划分

| 平面            | 前缀           | runner                   | VM?        | 关注点                       | 典型时长 |
| --------------- | -------------- | ------------------------ | ---------- | ---------------------------- | -------- |
| **Smoke**       | `test_`        | `runNixOSTest`           | QEMU       | 基本系统完整性               | ~1 min   |
| **NixOS-Plane** | `nixos_`       | `runNixOSTest`           | QEMU       | `nixos/*` 模块 + 系统服务    | 2–10 min |
| **HM-Plane**    | `home_`        | `runNixOSTest`           | QEMU       | `home/*` 包安装 + 运行时行为 | 2–8 min  |
| **Lib-Plane**   | `lib_`         | `runNixOSTest` (minimal) | QEMU 256MB | `lib/shared` 纯表达式        | <1 min   |
| **Integration** | `integration_` | `runNixOSTest`           | QEMU full  | NixOS + HM 联合激活          | 5–15 min |
| **nmt-Plane**   | `nmt_`         | `buildHomeManagerTest`   | **无 VM**  | HM dotfile 内容断言          | <10 s    |

### nmt vs HM-Plane 互补

每个有 dotfile 的 HM 工具两层覆盖：

```
home/core/exp/sys/base/fd.nix
  ├─ nmt_home_core_exp_sys_base_fd     dotfile 内容 (纯 eval, <10s)
  │    .config/fd/ignore: .git/ / *.bak 条目
  └─ home_core_exp_sys_base_fd         运行时行为 (QEMU VM, ~2min)
       fd --version, fd finds files by pattern

home/core/exp/sys/base/git.nix
  ├─ nmt_home_core_base_git            dotfile 内容 (纯 eval, <10s)
  │    .config/git/config: [user] name/email/branch/[delta]
  └─ home_core_exp_sys_base_git        运行时行为 (QEMU VM, ~2min)
       git --version, git init + commit + log
```

### nmt 适用判断表

| 条件                                      | 是否适合 nmt-Plane    |
| ----------------------------------------- | --------------------- |
| 工具通过 HM `programs.*` 选项生成配置文件 | ✅ 适合               |
| 配置文件是纯文本（非 `pkgs.formats.*`）   | ✅ 可内容断言         |
| 配置文件通过 `pkgs.formats.toml/json`     | ⚠️ 只能 exists 断言   |
| 工具仅 `home.packages` 安装，无 HM 配置   | ❌ 不适合，用 Plane 2 |
| 需要 GUI / Wayland / GPU 支持             | ❌ 不适合，用 Plane 2 |
| 需要服务运行时验证                        | ❌ 不适合，用 Plane 1 |

---

## 3. 完整测试矩阵

### 3.0 Smoke (1 test)

| check       | 文件            | 验证点                  |
| ----------- | --------------- | ----------------------- |
| `test_calc` | `test_calc.nix` | echo, 1+1=2, screenshot |

### 3.1 NixOS-Plane (30 tests)

| check                                                        | 验证点                                                      |
| ------------------------------------------------------------ | ----------------------------------------------------------- |
| `nixos_core_base_{boot,i18n,network,nix,sound,user}`         | systemd-boot / locale / networkd / flakes / pipewire / user |
| `nixos_core_base_{i18n_source,i18n_samesource}`              | T1.2 生产树 import（同源守卫） |
| `nixos_core_base_{wsl,portal}`                                | T7.1 WSL 表单求值 / T7.2 portal 能力门双律 |
| `nixos_core_base_sound_gate`                                   | T10.1 sound 策略轴门双律（pipewire 全栈 / none 整体减除） |
| `nixos_core_base_impermanence`                                | T5.14 回滚配方/单元排序/设备门/惰性律 |
| `nixos_core_drive_{amd,intel,nvidia}`                        | GPU driver toolchain                                        |
| `nixos_core_sec_{pam,polkit,secret_cmd_age,secret_cmd_sops}` | PAM / polkit / age / sops                                   |
| `nixos_core_srv_db_{mongodb,mysql,postgresql,redis}`         | service active + DB ops                                     |
| `nixos_core_srv_hardware_{bluetooth,printing}`               | bluetoothd / cups                                           |
| `nixos_core_srv_log_logrotate`                               | binary + timer                                              |
| `nixos_core_srv_monitor_policy`                               | 监控策略（export-modules 模式） |
| `nixos_core_srv_security_{ssh,keyring}`                      | sshd :22 / gnome-keyring                                    |
| `nixos_export_modules`                                        | T5.3 export/ 模块语义求值        |

> 合计：base(11 = 6 + i18n_source + samesource + wsl + portal + sound_gate) + impermanence(1) + drive(3) + sec(4) + db(4) + monitor(1) + hardware(2) + log(1) + security(2) + export(1) = **30**

### 3.2 HM-Plane (41 tests)

| check                                                                                           | 验证点                           |
| ----------------------------------------------------------------------------------------------- | -------------------------------- |
| `home_core_base_{fonts,i18n}`                                                                   | fc-list / fcitx5                 |
| `home_core_base_i18n_source`                                                                    | T1.2 生产树 import（同源守卫） |
| `home_core_exp_app_editor_nvim`                                                                 | nvim headless Lua                |
| `home_core_exp_sys_base_{atuin,bat,direnv,eza,fd,fzf,git,jq,ripgrep,starship,tmux,yazi,zoxide}` | binary + version + workflow      |
| `home_core_exp_sys_base_{fzf,git,starship}_source`                                               | T1.2 生产树 import（策略接线）   |
| `home_core_exp_sys_shell_{zsh,fish}`                                                            | binary / compinit / abbr         |
| `home_core_exp_sys_shell_zsh_source`                                                             | T1.2 生产树 import（shell 契约）|
| `home_core_exp_sys_{monitor,media,fs}`                                                          | btop+htop / mpv+ffmpeg / duf+tar |
| `home_core_sec`                                                                                 | module parses                    |
| `home_core_srv_notify_mako`                                                                     | mako + makoctl                   |
| `home_core_srv_security_gnupg`                                                                  | gpg + gpg-agent                  |
| `home_env_dev_{c,cpp,rust,go,python,typescript,java,lua,zig,nix,re}`                            | toolchain binary + hello-world   |
| `home_export_modules`                                                                          | T5.3 export/ 模块语义求值        |

> 合计：base(2) + i18n_source(1) + editor(1) + sys/base(13 + 3 source) + shell(2 + 1 source) + sys/monitor+media+fs(3) + sec(1) + notify(1) + security(1) + env/dev(11) + export(1) = **41**

### 3.3 Lib-Plane (12 tests)

| check | 验证点 |
| ------------------------------------ | --------------------------------- |
| `lib_shared_shared_{enum,fn,schema}` | 枚举语义 / fn 逻辑 / schema merge |
| `lib_shared_targets` | 事实源普查（T19.1）：hosts/ × 分类器 caps——裸金属 NixOS 主机恰一事实源、宿主持有形态零源、双源即红（迁移自身的失败模式即 Law A） |
| `lib_shared_deploy` | 部署面普查（T21.1）：T20.1 仿真升级为锁定测试——Law D 无说谎部署事实〔非 nixosHosts 上的 deploy.nix〕+ 发射覆盖双向精确〔colmenaHive nodes == 分类器 nixosHosts，零硬编码成员表〕+ 用户门存活〔targetUser = 策略用户，ssh 禁 root 禁密码——空或 root 即死门〕；attrNames-only 惰性链〔永不单树求值，drvPath 等价归 CI 门〕 |
| `lib_shared_overlays` | overlay 局部性普查（T24.2，run 38171937689 复跑裁决锁定）：canary 替换实例法——patches 应用到标记 stub 实例，每个被补成员〔cutter_patched/openldap/xdg-desktop-portal〕必须携带 canary 标记〔meta.description 穿透 overrideAttrs 存活〕，从任何外部句柄取包即失标即红——overlay 契约：改谁补谁，`prev`/`final` 即所应用实例自己的不动点 |
| `lib_shared_lang_version` | nix-types version 契约（T25.2，下游断言落地）：rev 答 where〔flake.nix 40-hex 钉点〕，version 答 what〔本测试 expected〕——`inputs.nix-types.lib.version == "3.6.0"`，bump = 两文件刻意决定，单侧漂移即一行红（诊断报出 lock rev / expected / observed 三方 + 双文件和解指引；变异检查实测） |
| `lib_shared_orc` | orc wallust copy-emitter 消费契约（T28）：一次 `homeManagerConfiguration` 经生产模块求值全部七站（mechanisms.md §6 清单）——dag 条目存在 + writeBoundary 后序 + `run cp --remove-destination <树>/<rel> "$HOME/<dest>/<rel>"` 全行〔源树携带文件 + 目的地键 + 旗标三合一——上游移文件/include 腐烂/destPrefix 拼写任一即红〕+ `run chmod u+w` 可写位；首跑即抓到 swaync 站点空 activation（swaync-config 树无 placeholder——include 零匹配的死寂失效模式），模块侧合成条目修复 + 配仓补丁存档 docs/feedback/；求值期裁决用纯子串搜索（lib.hasInfix 内部 builtins.match 禁含 store 路径模式——语言层限制绕行） |
| `lib_shared_orc_guard` | orc include-intent 守卫消费契约（T30，第 100 号）：第三代工具库回路收口——lock 钉的 orc 必须携带 T29 守卫〔05c658f〕。真 `shared.orc`〔生产句柄〕× 真 swaync-config 树四断言：非空 include 零匹配必须求值期爆〔`tryEval success = false`——T28 静默类的车队级死亡证明〕+ 正常路径零税〔copy 策略产 activation + 空 homeFiles〕+ `allowEmpty = true` 逃生门〔显式弃权产空不爆〕+ `include = []` 全接受〔census 不是 filter〕。第 97 号 version 契约同形：lock 答 WHERE、测试答 WHAT，单侧漂移即一行红 |
| `lib_shared_pdshell` | pdshell 加载器消费契约（T31，第 101 号——四库家族收口）：真 `shared.pdshells`〔生产句柄〕× flake.nix 同款实参五组断言：**census**〔25 成员精确集合——成员籍而非 docs-ssot 的计数；`_` 前缀静默排除与上游命名规则漂移的唯一绊网〕+ **face**〔`dev-shell-<member>` 名字注入〕+ **combinFrom**〔根 default 自身 buildInputs 为空，117 合并输入必须全部经十四个语言默认贡献——四探针各归一语言〕+ **lifecycle**〔段标记 + 继承先于自身 + FINAL SHELL OVERRIDE 导出身份轴 shell〕+ **NamedFile 隔离**〔renpy 自带引擎、不泄漏兄弟与跨作用域输入〕；变异双红（静默改名 / `_` 前缀）；T31r 沙箱重置后地面真值重著 |

### 3.4 Integration-Plane (1 test)

| check                       | 验证点                                            |
| --------------------------- | ------------------------------------------------- |
| `integration_hm_activation` | HM NixOS module wiring, user home, zsh/git/direnv |

### 3.5 nmt-Plane (16 tests, 零 VM)

| check                               | 文件                                    | 验证点                                       | 断言类型              |
| ----------------------------------- | --------------------------------------- | -------------------------------------------- | --------------------- |
| `nmt_home_core_exp_sys_base_git`            | `nmt/home/core/exp/sys/base/git.nix`            | .config/git/config: user/branch/delta        | exists+contains       |
| `nmt_home_core_exp_sys_base_starship`       | `nmt/home/core/exp/sys/base/starship.nix`       | .config/starship.toml: exists (scrubbed)     | exists                |
| `nmt_home_core_exp_sys_base_direnv`        | `nmt/home/core/exp/sys/base/direnv.nix`        | .config/direnv/direnvrc: nix-direnv          | exists+contains       |
| `nmt_home_core_exp_sys_base_atuin`          | `nmt/home/core/exp/sys/base/atuin.nix`          | .config/atuin/config.toml: exists (scrubbed) | exists                |
| `nmt_home_core_exp_sys_base_zoxide`         | `nmt/home/core/exp/sys/base/zoxide.nix`         | .zshrc: zoxide init                          | contains              |
| `nmt_home_core_exp_sys_base_tmux`           | `nmt/home/core/exp/sys/base/tmux.nix`           | .config/tmux/tmux.conf: history-limit        | exists+contains       |
| `nmt_home_core_exp_sys_base_bat`            | `nmt/home/core/exp/sys/base/bat.nix`            | .config/bat/config: --theme/--pager          | exists+contains       |
| `nmt_home_core_exp_sys_base_fd`     | `nmt/home/core/exp/sys/base/fd.nix`     | .config/fd/ignore: .git/ / \*.bak            | exists+contains       |
| `nmt_home_core_exp_sys_base_fzf`    | `nmt/home/core/exp/sys/base/fzf.nix`    | .zshrc: fzf sourced / layout=reverse         | exists+regex+contains |
| `nmt_home_core_exp_sys_base_ripgrep` | `nmt/home/core/exp/sys/base/ripgrep.nix` | .config/ripgrep/ripgreprc: --smart-case（leading-dash needle，T27.2 fork `--` 守卫的消费级回归证明） | exists+contains       |
| `nmt_home_core_exp_sys_base_yazi`   | `nmt/home/core/exp/sys/base/yazi.nix`   | yazi.toml exists / init.lua: full-border     | exists+contains       |
| `nmt_home_core_exp_sys_shell_zsh`   | `nmt/home/core/exp/sys/shell/zsh.nix`   | .zshrc: compinit/HISTSIZE                    | exists+contains       |
| `nmt_home_core_exp_sys_shell_fish`  | `nmt/home/core/exp/sys/shell/fish.nix`  | config.fish: greeting/abbr                   | exists+contains       |
| `nmt_home_core_exp_app_editor_nvim` | `nmt/home/core/exp/app/editor/nvim.nix` | .config/nvim/init-test.vim: nocompatible     | exists+contains       |
| `nmt_home_core_srv_security_gnupg`  | `nmt/home/core/srv/security/gnupg.nix`  | .gnupg/gpg.conf: use-agent                   | exists+contains       |
| `nmt_home_core_srv_notify_mako`     | `nmt/home/core/srv/notify/mako.nix`     | .config/mako/config: font/colors             | exists+contains       |

> 合计：exp/sys/base(11) + shell(2) + app/editor(1) + srv/security(1) + srv/notify(1) = **16**（T27.2 前表 7 行 check 名/路径陈旧〔`nmt_home_core_base_*`〕——本轮对齐 registry 实名，docs-ssot 只锚计数放过了名/路径漂移）

---

## 4. 目录结构

```
tests/
├── default.nix
├── test_calc.nix
├── nixos/core/{base,drive,sec,srv}/…
├── home/
│   ├── core/
│   │   ├── base/{fonts,i18n,i18n-source}.nix
│   │   ├── exp/
│   │   │   ├── app/editor/nvim.nix
│   │   │   └── sys/
│   │   │       ├── base/{atuin,bat,direnv,eza,fd,fzf,git,jq,ripgrep,starship,tmux,yazi,zoxide}.nix
│   │   │       ├── fs/default.nix
│   │   │       ├── media/default.nix
│   │   │       ├── monitor/default.nix
│   │   │       └── shell/{fish,zsh}.nix
│   │   ├── sec/default.nix
│   │   └── srv/
│   │       ├── notify/mako.nix
│   │       └── security/gnupg.nix
│   └── env/dev/{c,cpp,go,java,lua,nix,python,re,rust,typescript,zig}/default.nix
├── lib/shared/lang/{enum,fn,schema}.nix
├── integration/hm_activation.nix
└── nmt/
    ├── default.nix                        ← buildHomeManagerTest impl + registry
    └── home/
        └── core/
            ├── exp/
            │   ├── app/editor/nvim.nix
            │   └── sys/
            │       ├── base/{fd,fzf,yazi}.nix
            │       └── shell/{zsh,fish}.nix
            ├── base/{atuin,bat,direnv,git,starship,tmux,zoxide}.nix  (via nmt/ structure)
            └── srv/
                ├── notify/mako.nix
                └── security/gnupg.nix
```

> **注意：** nmt/ 中 `base/` 的 7 个工具文件实际位于 `nmt/home/core/exp/sys/base/` 下（
> atuin/bat/direnv/git/starship/tmux/zoxide），路径与 `home/core/exp/sys/base/` 对称。

---

## 5. 运行指南

```bash
# 全部（本地需要 KVM）
nix flake check

# nmt only — 最快，无 QEMU，无 KVM
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json \
  | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]" \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" -L --no-link

# 单个 nmt 测试
nix build .#checks.x86_64-linux.nmt_home_core_base_git -L
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_fd -L
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_fzf -L
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_yazi -L
nix build .#checks.x86_64-linux.nmt_home_core_exp_app_editor_nvim -L

# NixOS plane (需要 KVM)
nix build .#checks.x86_64-linux.nixos_core_srv_db_postgresql -L
nix build .#checks.x86_64-linux.nixos_core_base_user -L

# HM plane 单个
nix build .#checks.x86_64-linux.home_core_exp_sys_base_fd -L
nix build .#checks.x86_64-linux.home_env_dev_rust -L

# Integration
nix build .#checks.x86_64-linux.integration_hm_activation -L

# 按平面过滤
SYS=x86_64-linux
for PREFIX in nixos_ home_ lib_ integration_ test_; do
  nix eval ".#checks.${SYS}" \
    --apply "cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 ${#PREFIX} n == \"${PREFIX}\") cs)" \
    --json \
    | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]"
done
```

---

## 6. 设计原则与约束

### nmt 集成约束

| 约束                                                     | 原因                                     |
| -------------------------------------------------------- | ---------------------------------------- |
| `flake = false` on `inputs.nmt`                          | nmt 仓库无 flake.nix                     |
| Mirror: `github:Redskaber/nmt`                           | sourcehut 对所有 Nix fetcher UA 返回 403 |
| `buildHomeManagerTest` 在 `tests/nmt/default.nix` 中实现 | nmt 原生不提供此函数                     |
| scrubDerivations 替换所有 outPath                        | 防止 nmt eval 触发真实包构建             |
| hmModules from `inputs.home-manager`                     | 保证 HM option 语义与生产一致            |

### pkgs.formats.\* 与 scrubbing 的关系

| HM 配置路径                               | 文件生成方式          | 可断言内容        |
| ----------------------------------------- | --------------------- | ----------------- |
| `programs.git` (plain text)               | `home.file` 文本写入  | exists + contains |
| `programs.tmux` (plain text)              | `home.file` 文本写入  | exists + contains |
| `programs.starship` (formats.toml)        | derivation → scrubbed | exists only       |
| `programs.atuin` (formats.toml)           | derivation → scrubbed | exists only       |
| `programs.fd.ignores` (plain text)        | 直接写入文本          | exists + contains |
| `programs.ripgrep.arguments` (plain text) | 直接写入文本          | exists + contains |
| `programs.fzf` (shell init text)          | shell init 注入       | exists + contains |
| `programs.jq.colors` (plain text)         | 直接写入文本          | exists + contains |
| `programs.yazi.initLua` (plain text)      | home.file 写入        | exists + contains |
| `programs.yazi.settings` (formats.toml)   | derivation → scrubbed | exists only       |

### assertFileContains 针头约束

```
# ❌ WRONG — needle starts with "--", grep treats it as flag
contains = [ "--smart-case" ];

# ✅ CORRECT — strip leading "--"
contains = [ "smart-case" ];

# ✅ CORRECT — use regex key for pattern matching
regex = "smart.case";
```

### 平面隔离约束

| 约束                           | 原因                                |
| ------------------------------ | ----------------------------------- |
| NixOS-Plane 不导入 HM 模块     | 系统层/用户层边界明确，防止交叉依赖 |
| HM-Plane 不导入 NixOS 系统配置 | 同上                                |
| secrets/sops 不进入单元测试    | 测试环境无真实 age 密钥             |
| nmt 测试文件路径镜像源路径     | 路径语义：test 路径 = source 路径   |

### test 文件格式

```nix
# tests/nmt/home/**/*.nix — 固定接口，无需改动
{ lib, ... }:
lib.nmt.buildHomeManagerTest {
  description = "tool: …";
  modules = [{ home.username = "testuser"; … }];
  tests = {
    "tool: file exists"   = { path = ".config/…"; exists   = true; };
    "tool: value written" = { path = ".config/…"; contains = [ "…" ]; };
    "tool: regex match"   = { path = ".config/…"; regex    = "pattern"; };
  };
}
```

---

## 7. 扩展新测试

### 新增 nmt-Plane 测试 (checklist)

```nix
# 1. 判断: 工具是否生成可断言的 dotfile?
#    - programs.foo → generates ~/.config/foo/config (plain text)? → YES
#    - home.packages = [ foo ]? → NO, 用 Plane 2

# 2. 创建测试文件 (路径镜像源路径)
# tests/nmt/home/core/exp/sys/base/new-tool.nix
{ lib, ... }:
lib.nmt.buildHomeManagerTest {
  description = "new-tool: config written";
  modules = [{
    home = { username = "testuser"; homeDirectory = "/home/testuser"; stateVersion = "25.11"; };
    programs.new-tool = {
      enable = true;
      someOption = "value";
    };
  }];
  tests = {
    "new-tool: config exists"   = { path = ".config/new-tool/config"; exists = true; };
    "new-tool: setting written" = { path = ".config/new-tool/config"; contains = [ "value" ]; };
  };
}

# 3. 注册到 tests/nmt/default.nix
nmt_home_core_exp_sys_base_new_tool = buildTest ./home/core/exp/sys/base/new-tool.nix;

# 4. tests/default.nix 无需修改 — 自动合并 (import ./nmt { ... })

# 5. 验证
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_new_tool -L
```

### scrubbing 问题排查

```
错误: "@some-pkg@/bin/some-pkg: No such file or directory"
原因: 该包被 scrubDerivations 替换，需加入 whitelist
修复: 在 tests/nmt/default.nix whitelist 中添加:
      inherit (pkgs) some-pkg;
```

### 新增 NixOS-Plane 测试

```nix
# tests/nixos/core/srv/db/newdb.nix
{ ... }:
{
  name = "nixos_core_srv_db_newdb";
  nodes.machine = { pkgs, shared, ... }: {
    imports = [ shared.nixosModules.default ];
    nixos.core.srv.db.newdb.enable = true;
  };
  testScript = ''
    machine.wait_for_unit("newdb.service")
    machine.succeed("newdb --version")
  '';
}

# 注册到 tests/default.nix
nixos_core_srv_db_newdb = nixosTest ./nixos/core/srv/db/newdb.nix;
```

### 新增 HM-Plane 测试

```nix
# tests/home/core/exp/sys/base/new-tool.nix
{ pkgs, shared, ... }:
{
  name = "home_core_exp_sys_base_new_tool";
  nodes.machine = { ... }: {
    home-manager.users.testuser = { pkgs, ... }: {
      programs.new-tool.enable = true;
    };
  };
  testScript = ''
    machine.wait_for_unit("home-manager-testuser.service")
    machine.succeed("new-tool --version")
  '';
}

# 注册到 tests/default.nix
home_core_exp_sys_base_new_tool = nixosTest ./home/core/exp/sys/base/new-tool.nix;
```

---

## 8. CI 集成

CI 流水线（`.github/workflows/ci.yml`）将测试平面映射到独立 job，实现最大并行度与最快反馈：

```
STAGE 1: lint              [always]      静态分析 + 浅层 eval（无构建）
    │
    ├─► STAGE 2: nmt-plane [parallel]   纯 Nix eval，无 KVM — 最快反馈
    ├─► STAGE 3: devshells [parallel]   devShell dry-run 矩阵
    ├─► STAGE 4: security  [parallel]   SOPS 完整性审计
    │
    └─► STAGE 5: vm-tests  [after nmt]  QEMU 测试（需 KVM），按平面并行子矩阵
            ├── smoke        (test_)
            ├── nixos        (nixos_)
            ├── home-lib     (home_ + lib_)
            └── integration  (integration_)

STAGE 6: summary           [always]     汇总各阶段状态
```

### 平面 → CI Job 映射

| 平面        | CI Job                   | 前缀           | KVM   | 依赖      |
| ----------- | ------------------------ | -------------- | ----- | --------- |
| Smoke       | `vm-tests (smoke)`       | `test_`        | ✓     | nmt-plane |
| NixOS       | `vm-tests (nixos)`       | `nixos_`       | ✓     | nmt-plane |
| HM + Lib    | `vm-tests (home-lib)`    | `home_` `lib_` | ✓     | nmt-plane |
| Integration | `vm-tests (integration)` | `integration_` | ✓     | nmt-plane |
| **nmt**     | **`nmt-plane`**          | `nmt_`         | **✗** | lint      |

### 动态检测 (no manual list maintenance)

CI 使用 `nix eval --apply` 按前缀过滤 checks，**新增测试自动被 CI 发现**：

```bash
# nmt 平面发现示例
nix eval ".#checks.x86_64-linux" \
  --apply 'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json
```

### 本地快速预检（push 前）

```bash
# 1. nmt 平面（<30s，无 QEMU）
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]" \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" --no-link

# 2. statix lint
nix run nixpkgs#statix -- check .

# 3. 结构验证（无构建）
nix eval .#nixosConfigurations --apply builtins.attrNames --json
nix eval .#homeConfigurations  --apply builtins.attrNames --json
nix eval .#checks.x86_64-linux --apply builtins.attrNames --json
```

### 测试计数 (2026-10-10，机器强制：`tests/docs-ssot.nix` — T8.1；本地速查：`scripts/sh/test-count.sh`)

| 平面        | 数量   | KVM   | 备注                                                                    |
| ----------- | ------ | ----- | ----------------------------------------------------------------------- |
| Smoke       | 1      | ✓     |                                                                         |
| NixOS       | 30     | ✓     | base(11=6+i18n_source+samesource+wsl+portal+sound_gate)+drive(3)+sec(4)+db(4)+hardware(2)+log(1)+security(2)+export(1)+monitor(1)+impermanence(1，T5.14：三组独立 nixosSystem 求值锁定回滚配方/单元排序/设备门/neededForBoot/bind mounts/惰性律) |
| HM          | 41     | ✓     | base(2)+i18n_source(1)+editor(1)+sys/base(13+3 source)+shell(2+1 source)+sys(3)+sec(1)+srv(2)+dev(11)+export(1) |
| Lib         | 12     | ✓     | enum + fn + schema + caps（T4.0 能力表契约）+ validate（T4.1 Result 铁路）+ targets（T19.1 事实源普查）+ deploy（T21.1 部署面普查）+ overlays（T24.2 overlay 局部性普查）+ version（T25.2 nix-types version 契约——rev 答 where、version 答 what，bump 两文件刻意决定）+ orc（T28 orc wallust copy-emitter 消费契约——七站全契约，首跑抓 swaync 空 activation）+ orc-guard（T30 include-intent 守卫消费契约——三代工具库回路收口：T28 抓缺陷 → T29 守卫回馈上游 05c658f → 本轮消费回来）+ pdshell（T31 加载器消费契约——四库家族收口：census/face/combinFrom/lifecycle/NamedFile 五组，变异双红） |
| Integration | 1      | ✓     |                                                                         |
| **nmt**     | **16** | **✗** | exp/sys/base(11)+shell(2)+app/editor(1)+srv(2)；T27.2 +1：ripgrep——fork `--` 守卫的消费级回归证明（leading-dash needle） |
| **Total**   | **101** |       | VM 85 + nmt 16（另有 6 个仓库卫生 checks：pre-commit-check + docs-ssot-check + testscript-syntax-check + module-reachability-check + platform-grammar-check + cache-ssot-check）→ 107 checks（cache-ssot +1 门：cache-ssot-check——舰队缓存身份漂移门〔身份（名/URL/公钥）单源声明于 lib/shared/lang/const.nix（shared.const.cache.fleet），分发按各面能力：platform/nixos/…/nix.nix 按值消费不可漂移；无法求值的面持钉死字面镜像——CI workflows、cachix.just（YAML/shell 无法 import nix）、cache.md 散文；flake.nix 的 nixConfig 第 27 轮移除——入口层零缓存身份（真实消费面已闭合、能求值面不再持字面量、nixConfig 信任语义对消费者是负债），门把 flake.nix 的沉默钉为断言（标识符/URL/公钥三禁——任何 nixConfig 回归即红）；改名/换钥后字面量不跟随即此门红〕；T46 +1 门：platform-grammar-check——平台目录文法形状门〔纯 readDir 树形遍历：platform/ 顶层只允许标签目录；<tag>/ 下只允许 system/+home/ 保留子域（至少其一）；每域必持 default.nix 正则门；域级负载只允许模块目录——裸 .nix 文件 = v3 arch 行尸体类、无门目录 = 对所有门不可见；run #369 的 82 具 v3 尸体全部此缺陷类，可达性门图游走后抓到、形状门地址空间层直接拒绝；无豁免账本——文法演进与门同提交〕；T41 +1 门：module-reachability-check——模块树可达性门〔home/ + platform/ 每个 default.nix 目录必须从 flake 求值面可达：9 图根（3 system + 5 home 双门 + devShells 域根）+ 静态/动态双形态边提取 + 注释剥离 + 豁免账本自愈双绊线；首扫即抓 exp/sys/re 悬空——第 19 轮 srv/cache 同类，死代码对 14 道门不可见的类别根治；变异重放：摘 ./cache 接线门必红；第 26 轮扩展（run 38632140441 类）：无门目录引用不变量——import 形态静态引用指向审计树内存在但无 default.nix 门的目录（v3 顶层门残留被尸体在场掩盖、扫除后悬空的类别），判别律双方向精确（尾斜杠 = 动态路由前缀跳过、树外目标 = 数据绑定跳过），全源扫描 420 文件、修复树上零违规〕；T32 +1 门：testscript-syntax-check——全部组合后 testScript 的 python 语法门〔求值层直调模块取真文、构建层 compile()〕+ lib_shared_orc testScript 修复〔多行 contractHeld 拼进单行 `#` 注释——CI lib plane 红根因〕；T31 +1：lib_shared_pdshell——pdshell 加载器消费契约〔四库家族收口：nix-types 97 / nmt 98 / orc 99+100 / pdshell 101〕；T30 +1：lib_shared_orc_guard——orc include-intent 守卫消费契约〔lock 答 WHERE、测试答 WHAT〕+ swaync 合成条目退役〔swaync-config c8818d9 placeholder 采纳——干净表示〕；T28 +1：lib_shared_orc——七站 wallust copy-emitter 消费契约，首跑抓 swaync 空 activation〔include 零匹配的死寂失效模式〕；T27.2 前序：nmt_home_core_exp_sys_base_ripgrep；T25.2 前序：lib_shared_lang_version；T24.2 前序：lib_shared_overlays） |
