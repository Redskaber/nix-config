# NixOS Config — Test Matrix

> `docs/tests/test-matrix.md`
> Updated: 2026-05-11

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
├── lib/                     ← Lib-Plane  (pure Nix eval)
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

```
home/core/exp/sys/base/git.nix
  ├─ nmt_home_core_base_git       dotfile 内容 (纯 eval, <10s)
  │    .config/git/config: [user] name/email/branch/[delta]
  └─ home_core_exp_sys_base_git   运行时行为 (QEMU VM, ~2min)
       git --version, git init + commit + log
```

---

## 3. 完整测试矩阵

### 3.0 Smoke

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

### 3.5 nmt-Plane (13 tests, 零 VM)

| check                              | 文件                              | 验证点                                 |
| ---------------------------------- | --------------------------------- | -------------------------------------- |
| `nmt_home_core_base_git`           | `nmt/home/core/base/git.nix`      | .config/git/config: user/branch/delta  |
| `nmt_home_core_base_starship`      | `nmt/home/core/base/starship.nix` | .config/starship.toml: [character]     |
| `nmt_home_core_base_direnv`        | `nmt/home/core/base/direnv.nix`   | .config/direnv/direnvrc: nix-direnv    |
| `nmt_home_core_base_atuin`         | `nmt/home/core/base/atuin.nix`    | .config/atuin/config.toml: search_mode |
| `nmt_home_core_base_zoxide`        | `nmt/home/core/base/zoxide.nix`   | shell init: zoxide init                |
| `nmt_home_core_base_tmux`          | `nmt/home/core/base/tmux.nix`     | .config/tmux/tmux.conf: history-limit  |
| `nmt_home_core_base_bat`           | `nmt/home/core/base/bat.nix`      | .config/bat/config: --theme/--pager    |
| `nmt_home_core_exp_sys_shell_zsh`  | `nmt/…/shell/zsh.nix`             | .zshrc: compinit/HISTSIZE              |
| `nmt_home_core_exp_sys_shell_fish` | `nmt/…/shell/fish.nix`            | config.fish: greeting/abbr             |
| `nmt_home_core_exp_app_nvim`       | `nmt/home/core/exp/app/nvim.nix`  | .profile: EDITOR                       |
| `nmt_home_core_srv_gnupg`          | `nmt/home/core/srv/gnupg.nix`     | .gnupg/gpg.conf: use-agent             |
| `nmt_home_core_srv_mako`           | `nmt/home/core/srv/mako.nix`      | .config/mako/config: font/colors       |

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
    ├── default.nix                ← buildHomeManagerTest impl + registry
    └── home/
        ├── core/base/{atuin,bat,direnv,git,starship,tmux,zoxide}.nix
        ├── core/srv/{gnupg,mako}.nix
        └── core/exp/{app/nvim,sys/shell/{zsh,fish}}.nix
```

---

## 5. 运行指南

```bash
# 全部
nix flake check

# nmt only (FAST, no QEMU)
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  | tr -d '[]"' | tr ' ' '\n' \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" -L

# 单个
nix build .#checks.x86_64-linux.nmt_home_core_base_git -L
nix build .#checks.x86_64-linux.nixos_core_srv_db_postgresql -L
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
  };
}
```

---

## 7. 扩展新测试

### 新增 nmt-Plane 测试

```nix
# 1. tests/nmt/home/core/base/new-tool.nix
{ lib, ... }:
lib.nmt.buildHomeManagerTest {
  description = "new-tool: config written";
  modules = [{
    home = { username = "testuser"; homeDirectory = "/home/testuser"; stateVersion = "25.11"; };
    programs.new-tool.enable = true;
  }];
  tests = {
    "new-tool: config exists"   = { path = ".config/new-tool/config"; exists = true; };
    "new-tool: setting written" = { path = ".config/new-tool/config"; contains = [ "value" ]; };
  };
}

# 2. tests/nmt/default.nix
nmt_home_core_base_new_tool = buildTest ./home/core/base/new-tool.nix;
# 3. tests/default.nix 无需修改 — 自动合并
```

---

## 8. CI 集成

```yaml
# Stage 1: nmt (零 VM, 无 KVM 依赖, 最快)
- name: nmt-Plane
  run: |
    CHECKS=$(nix eval .#checks.x86_64-linux --apply \
      'cs: builtins.attrNames (builtins.filterAttrs
        (n: _: builtins.substring 0 4 n == "nmt_") cs)' --json | jq -r '.[]')
    for c in $CHECKS; do nix build ".#checks.x86_64-linux.$c" -L --no-link; done

# Stage 2+: nixos_* / home_* / integration_* (需要 KVM)
```

### 测试计数

| 平面        | 数量   | KVM   |
| ----------- | ------ | ----- |
| Smoke       | 1      | ✓     |
| NixOS       | 21     | ✓     |
| HM          | 35     | ✓     |
| Lib         | 3      | ✓     |
| Integration | 1      | ✓     |
| **nmt**     | **13** | **✗** |
| **Total**   | **74** |       |
