# NixOS Config — Test Matrix

> `docs/tests/test-matrix.md`
> Updated: 2026-05-12

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

### 3.1 NixOS-Plane (21 tests)

| check                                                        | 验证点                                                      |
| ------------------------------------------------------------ | ----------------------------------------------------------- |
| `nixos_core_base_{boot,i18n,network,nix,sound,user}`         | systemd-boot / locale / networkd / flakes / pipewire / user |
| `nixos_core_drive_{amd,intel,nvidia}`                        | GPU driver toolchain                                        |
| `nixos_core_sec_{pam,polkit,secret_cmd_age,secret_cmd_sops}` | PAM / polkit / age / sops                                   |
| `nixos_core_srv_db_{mongodb,mysql,postgresql,redis}`         | service active + DB ops                                     |
| `nixos_core_srv_desktop_flatpak`                             | flatpak version                                             |
| `nixos_core_srv_hardware_{bluetooth,printing}`               | bluetoothd / cups                                           |
| `nixos_core_srv_log_logrotate`                               | binary + timer                                              |
| `nixos_core_srv_security_{ssh,keyring}`                      | sshd :22 / gnome-keyring                                    |

### 3.2 HM-Plane (35 tests)

| check                                                                                           | 验证点                           |
| ----------------------------------------------------------------------------------------------- | -------------------------------- |
| `home_core_base_{fonts,i18n,portal}`                                                            | fc-list / fcitx5 / xdg-portal    |
| `home_core_exp_sys_base_{atuin,bat,direnv,eza,fd,fzf,git,jq,ripgrep,starship,tmux,yazi,zoxide}` | binary + version + workflow      |
| `home_core_exp_sys_shell_{zsh,fish}`                                                            | binary / compinit / abbr         |
| `home_core_exp_sys_{monitor,media,fs}`                                                          | btop+htop / mpv+ffmpeg / duf+tar |
| `home_core_sec`                                                                                 | module parses                    |
| `home_core_srv_notify_mako`                                                                     | mako + makoctl                   |
| `home_core_srv_security_gnupg`                                                                  | gpg + gpg-agent                  |
| `home_core_exp_app_editor_nvim`                                                                 | nvim headless Lua                |
| `home_env_dev_{c,cpp,rust,go,python,typescript,java,lua,zig,nix,re}`                            | toolchain binary + hello-world   |

### 3.3 Lib-Plane (3 tests)

| check                                | 验证点                            |
| ------------------------------------ | --------------------------------- |
| `lib_shared_shared_{enum,fn,schema}` | 枚举语义 / fn 逻辑 / schema merge |

### 3.4 Integration-Plane (1 test)

| check                       | 验证点                                            |
| --------------------------- | ------------------------------------------------- |
| `integration_hm_activation` | HM NixOS module wiring, user home, zsh/git/direnv |

### 3.5 nmt-Plane (17 tests, 零 VM)

| check                                | 文件                                     | 验证点                                       | 断言类型              |
| ------------------------------------ | ---------------------------------------- | -------------------------------------------- | --------------------- |
| `nmt_home_core_base_git`             | `nmt/home/core/base/git.nix`             | .config/git/config: user/branch/delta        | exists+contains       |
| `nmt_home_core_base_starship`        | `nmt/home/core/base/starship.nix`        | .config/starship.toml: exists (scrubbed)     | exists                |
| `nmt_home_core_base_direnv`          | `nmt/home/core/base/direnv.nix`          | .config/direnv/direnvrc: nix-direnv          | exists+contains       |
| `nmt_home_core_base_atuin`           | `nmt/home/core/base/atuin.nix`           | .config/atuin/config.toml: exists (scrubbed) | exists                |
| `nmt_home_core_base_zoxide`          | `nmt/home/core/base/zoxide.nix`          | .zshrc: zoxide init                          | contains              |
| `nmt_home_core_base_tmux`            | `nmt/home/core/base/tmux.nix`            | .config/tmux/tmux.conf: history-limit        | exists+contains       |
| `nmt_home_core_base_bat`             | `nmt/home/core/base/bat.nix`             | .config/bat/config: --theme/--pager          | exists+contains       |
| `nmt_home_core_exp_sys_base_fd`      | `nmt/home/core/exp/sys/base/fd.nix`      | .config/fd/ignore: .git/ / \*.bak            | exists+contains       |
| `nmt_home_core_exp_sys_base_fzf`     | `nmt/home/core/exp/sys/base/fzf.nix`     | .zshrc: fzf sourced / layout=reverse         | exists+regex+contains |
| `nmt_home_core_exp_sys_base_jq`      | `nmt/home/core/exp/sys/base/jq.nix`      | .config/jq/jq: null/strings colors           | exists+contains       |
| `nmt_home_core_exp_sys_base_ripgrep` | `nmt/home/core/exp/sys/base/ripgrep.nix` | .config/ripgrep/ripgreprc: smart-case/follow | exists+contains       |
| `nmt_home_core_exp_sys_base_yazi`    | `nmt/home/core/exp/sys/base/yazi.nix`    | yazi.toml exists / init.lua: full-border     | exists+contains       |
| `nmt_home_core_exp_sys_shell_zsh`    | `nmt/…/shell/zsh.nix`                    | .zshrc: compinit/HISTSIZE                    | exists+contains       |
| `nmt_home_core_exp_sys_shell_fish`   | `nmt/…/shell/fish.nix`                   | config.fish: greeting/abbr                   | exists+contains       |
| `nmt_home_core_exp_app_nvim`         | `nmt/home/core/exp/app/nvim.nix`         | .config/nvim/init-test.vim: nocompatible     | exists+contains       |
| `nmt_home_core_srv_gnupg`            | `nmt/home/core/srv/gnupg.nix`            | .gnupg/gpg.conf: use-agent                   | exists+contains       |
| `nmt_home_core_srv_mako`             | `nmt/home/core/srv/mako.nix`             | .config/mako/config: font/colors             | exists+contains       |

---

## 4. 目录结构

```
tests/
├── default.nix
├── test_calc.nix
├── nixos/core/{base,drive,sec,srv}/…
├── home/{core,env}/…
├── lib/shared/shared/{enum,fn,schema}.nix
├── integration/hm_activation.nix
└── nmt/
    ├── default.nix                        ← buildHomeManagerTest impl + registry
    └── home/
        ├── core/
        │   ├── base/{atuin,bat,direnv,git,starship,tmux,zoxide}.nix
        │   ├── exp/
        │   │   ├── app/nvim.nix
        │   │   └── sys/
        │   │       ├── base/{fd,fzf,jq,ripgrep,yazi}.nix
        │   │       └── shell/{zsh,fish}.nix
        │   └── srv/{gnupg,mako}.nix
        └── (env/dev/* — 纯 home.packages 安装，无 dotfile → Plane 2 覆盖)
```

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
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_ripgrep -L
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_yazi -L

# NixOS plane (需要 KVM)
nix build .#checks.x86_64-linux.nixos_core_srv_db_postgresql -L
nix build .#checks.x86_64-linux.nixos_core_base_user -L

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

# 2. 创建测试文件
# tests/nmt/home/core/base/new-tool.nix
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
nmt_home_core_base_new_tool = buildTest ./home/core/base/new-tool.nix;

# 4. tests/default.nix 无需修改 — 自动合并 (import ./nmt { ... })

# 5. 验证
nix build .#checks.x86_64-linux.nmt_home_core_base_new_tool -L
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

### 测试计数 (2026-05-12)

| 平面        | 数量   | KVM   | 备注                            |
| ----------- | ------ | ----- | ------------------------------- |
| Smoke       | 1      | ✓     |                                 |
| NixOS       | 21     | ✓     |                                 |
| HM          | 35     | ✓     |                                 |
| Lib         | 3      | ✓     |                                 |
| Integration | 1      | ✓     |                                 |
| **nmt**     | **17** | **✗** | +5 (fd, fzf, jq, ripgrep, yazi) |
| **Total**   | **78** |       |                                 |
