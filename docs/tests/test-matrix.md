# NixOS Config — Test Matrix

> `docs/tests/test-matrix.md`
> Updated: 2026-05-10

---

## 目录

1. [架构概述](#1-架构概述)
2. [测试平面划分](#2-测试平面划分)
3. [完整测试矩阵](#3-完整测试矩阵)
   - 3.1 Smoke / Sanity
   - 3.2 NixOS-Plane
   - 3.3 Home-Manager-Plane (nixosTest)
   - 3.4 Lib-Plane
   - 3.5 Integration-Plane
   - 3.6 nmt-Plane (NEW)
4. [目录结构](#4-目录结构)
5. [运行指南](#5-运行指南)
6. [设计原则与约束](#6-设计原则与约束)
7. [扩展新测试](#7-扩展新测试)
8. [CI 集成](#8-ci-集成)

---

## 1. 架构概述

```
tests/
├── default.nix              ← 注册表: 所有平面 checks 汇总 (data-driven)
├── test_calc.nix            ← Smoke 基线 (保留原始)
│
├── nixos/                   ← NixOS-Plane (QEMU VM)
│   └── core/
│       ├── base/            ← boot, user, network, i18n, nix, sound
│       ├── drive/           ← amd, intel, nvidia
│       ├── sec/             ← polkit, pam, sops, age
│       └── srv/
│           ├── db/          ← postgresql, mysql, redis, mongodb
│           ├── desktop/     ← flatpak
│           ├── hardware/    ← bluetooth, printing
│           ├── log/         ← logrotate
│           └── security/    ← ssh, keyring
│
├── home/                    ← HM-Plane (QEMU VM + packages)
│   ├─── core/
│   │    ├── base/            ← fonts, i18n, portal
│   │    ├── sec/             ← placeholder (module eval)
│   │    ├── srv/
│   │    │   ├── notify/      ← mako
│   │    │   └── security/    ← gnupg
│   │    └── exp/sys/
│   │        ├── base/        ← git, direnv, starship, atuin, tmux, bat,
│   │        │                  fzf, ripgrep, eza, fd, jq, zoxide
│   │        ├── shell/       ← zsh, fish
│   │        ├── monitor/     ← btop, htop, bottom
│   │        ├── media/       ← mpv, ffmpeg
│   │        ├── fs/          ← duf, compress tools
│   │        └── misc/        ← yazi
│   └── env/dev/             ← c, cpp, rust, go, python, typescript,
│                              java, lua, zig, nix, re
│
├── lib/                     ← Lib-Plane (pure Nix eval)
│   └── shared/shared/
│       ├── enum.nix
│       ├── fn.nix
│       └── schema.nix
│
├── integration/             ← Integration-Plane (NixOS + HM 联合)
│   └── hm_activation.nix
│
└── nmt/                     ← nmt-Plane (零 VM, 纯 eval) ← NEW
    ├── default.nix          ← nmt 注册表
    └── home/
        ├── core/
        │   ├── base/        ← git, starship, direnv, atuin, zoxide, tmux, bat
        │   ├── srv/         ← gnupg, mako
        │   └── exp/sys/
        │       ├── shell/   ← zsh, fish
        │       └── app/     ← nvim
        └── env/dev/         ← git (dev 配置)
```

---

## 2. 测试平面划分

| 平面                  | 前缀           | runner                   | VM?            | 关注点                        | 典型时长 |
| --------------------- | -------------- | ------------------------ | -------------- | ----------------------------- | -------- |
| **Smoke**             | `test_`        | `runNixOSTest`           | QEMU           | 基本系统完整性                | ~1 min   |
| **NixOS-Plane**       | `nixos_`       | `runNixOSTest`           | QEMU           | `nixos/*` 模块 + 系统服务     | 2–10 min |
| **HM-Plane**          | `home_`        | `runNixOSTest`           | QEMU           | `home/*` 包安装 + 运行时行为  | 2–8 min  |
| **Lib-Plane**         | `lib_`         | `runNixOSTest` (minimal) | QEMU (256 MiB) | `lib/shared` 纯表达式         | <1 min   |
| **Integration-Plane** | `integration_` | `runNixOSTest`           | QEMU (full)    | NixOS + HM 联合激活           | 5–15 min |
| **nmt-Plane** ← NEW   | `nmt_`         | `buildHomeManagerTest`   | **无 VM**      | HM dotfile 内容断言 (纯 eval) | <10 s    |

### 平面隔离规则

- **NixOS-Plane** 不导入任何 `home-manager` 模块
- **HM-Plane** 不测试系统服务（sshd, postgresql, …）；验证包存在 + 运行时输出
- **Lib-Plane** 不启动任何 systemd 服务；`nix-instantiate --eval` 断言
- **Integration-Plane** 可导入两个平面的模块，必须有明确的集成目的
- **nmt-Plane** 不启动 QEMU，不验证运行时行为；断言 dotfile 内容正确

### nmt vs HM-Plane 互补关系

```
home/core/exp/sys/base/git.nix
        │
        ├─ nmt_home_core_base_git          ← dotfile 内容断言 (纯 eval, <10s)
        │    .config/git/config contains:
        │    [user], name, email, defaultBranch, delta
        │
        └─ home_core_exp_sys_base_git      ← 运行时行为验证 (QEMU VM, ~2min)
               git --version, git commit, git log
```

---

## 3. 完整测试矩阵

### 3.1 Smoke / Sanity

| check 名称  | 文件            | 验证点                  |
| ----------- | --------------- | ----------------------- |
| `test_calc` | `test_calc.nix` | echo, 1+1=2, screenshot |

---

### 3.2 NixOS-Plane

#### core/base

| check 名称                | 文件                          | 验证点                                             |
| ------------------------- | ----------------------------- | -------------------------------------------------- |
| `nixos_core_base_boot`    | `nixos/core/base/boot.nix`    | systemd-boot, kernel cmdline, /boot/EFI            |
| `nixos_core_base_i18n`    | `nixos/core/base/i18n.nix`    | LANG=en_US.UTF-8, zh_CN locale, fcitx5 binary      |
| `nixos_core_base_network` | `nixos/core/base/network.nix` | networkd active, lo up, hostname, ping localhost   |
| `nixos_core_base_nix`     | `nixos/core/base/nix.nix`     | nix --version, flakes enabled, substituters config |
| `nixos_core_base_sound`   | `nixos/core/base/sound.nix`   | pipewire active, wireplumber, pactl present        |
| `nixos_core_base_user`    | `nixos/core/base/user.nix`    | user exists, home dir, sudo, shell assignment      |

#### core/drive

| check 名称                | 文件                          | 验证点                                  |
| ------------------------- | ----------------------------- | --------------------------------------- |
| `nixos_core_drive_amd`    | `nixos/core/drive/amd.nix`    | amdgpu module, mesa, vulkan utils       |
| `nixos_core_drive_intel`  | `nixos/core/drive/intel.nix`  | i915 module, intel-media-driver, vainfo |
| `nixos_core_drive_nvidia` | `nixos/core/drive/nvidia.nix` | OpenGL driver libs, glxinfo, lspci      |

#### core/sec

| check 名称                       | 文件                                 | 验证点                              |
| -------------------------------- | ------------------------------------ | ----------------------------------- |
| `nixos_core_sec_pam`             | `nixos/core/sec/pam.nix`             | /etc/pam.d/login exists, limits     |
| `nixos_core_sec_polkit`          | `nixos/core/sec/polkit.nix`          | polkit service active, pkcheck      |
| `nixos_core_sec_secret_cmd_age`  | `nixos/core/sec/secret/cmd/age.nix`  | age binary, keygen, encrypt/decrypt |
| `nixos_core_sec_secret_cmd_sops` | `nixos/core/sec/secret/cmd/sops.nix` | sops binary, --version              |

#### core/srv/db

| check 名称                     | 文件                               | 验证点                                            |
| ------------------------------ | ---------------------------------- | ------------------------------------------------- |
| `nixos_core_srv_db_postgresql` | `nixos/core/srv/db/postgresql.nix` | service active, :5432, peer auth, health_check 表 |
| `nixos_core_srv_db_mysql`      | `nixos/core/srv/db/mysql.nix`      | service active, socket auth, ensureDB/User        |
| `nixos_core_srv_db_redis`      | `nixos/core/srv/db/redis.nix`      | service active, PING/PONG, SET/GET/DEL            |
| `nixos_core_srv_db_mongodb`    | `nixos/core/srv/db/mongodb.nix`    | service active, :27017, mongosh ping, insert/find |

#### core/srv/desktop

| check 名称                       | 文件                                 | 验证点                       |
| -------------------------------- | ------------------------------------ | ---------------------------- |
| `nixos_core_srv_desktop_flatpak` | `nixos/core/srv/desktop/flatpak.nix` | flatpak version, remote-list |

#### core/srv/hardware (NEW)

| check 名称                          | 文件                                    | 验证点                                       |
| ----------------------------------- | --------------------------------------- | -------------------------------------------- |
| `nixos_core_srv_hardware_bluetooth` | `nixos/core/srv/hardware/bluetooth.nix` | bluetoothd unit, bluetoothctl binary, rfkill |
| `nixos_core_srv_hardware_printing`  | `nixos/core/srv/hardware/printing.nix`  | cups service active, lpstat, :631            |

#### core/srv/log + security

| check 名称                        | 文件                                  | 验证点                            |
| --------------------------------- | ------------------------------------- | --------------------------------- |
| `nixos_core_srv_log_logrotate`    | `nixos/core/srv/log/logrotate.nix`    | binary, config valid, timer       |
| `nixos_core_srv_security_ssh`     | `nixos/core/srv/security/ssh.nix`     | sshd :22, PasswordAuth=no         |
| `nixos_core_srv_security_keyring` | `nixos/core/srv/security/keyring.nix` | gnome-keyring-daemon, secret-tool |

---

### 3.3 Home-Manager-Plane (nixosTest)

#### core/base

| check 名称              | 文件                        | 验证点                                       |
| ----------------------- | --------------------------- | -------------------------------------------- |
| `home_core_base_fonts`  | `home/core/base/fonts.nix`  | fc-list runs, Noto fonts present, /etc/fonts |
| `home_core_base_i18n`   | `home/core/base/i18n.nix`   | LANG=en_US.UTF-8, fcitx5 binary              |
| `home_core_base_portal` | `home/core/base/portal.nix` | xdg-desktop-portal binary, portal unit       |

#### core/exp/sys/base

| check 名称                        | 文件                                  | 验证点                                  |
| --------------------------------- | ------------------------------------- | --------------------------------------- |
| `home_core_exp_sys_base_git`      | `home/core/exp/sys/base/git.nix`      | git binary, --version, commit workflow  |
| `home_core_exp_sys_base_direnv`   | `home/core/exp/sys/base/direnv.nix`   | direnv binary, allow/deny               |
| `home_core_exp_sys_base_starship` | `home/core/exp/sys/base/starship.nix` | starship binary, --version              |
| `home_core_exp_sys_base_atuin`    | `home/core/exp/sys/base/atuin.nix`    | atuin binary, --version                 |
| `home_core_exp_sys_base_tmux`     | `home/core/exp/sys/base/tmux.nix`     | tmux binary, new-session, kill-server   |
| `home_core_exp_sys_base_bat`      | `home/core/exp/sys/base/bat.nix`      | bat binary, --version, syntax highlight |
| `home_core_exp_sys_base_fzf`      | `home/core/exp/sys/base/fzf.nix`      | fzf binary, --version                   |
| `home_core_exp_sys_base_ripgrep`  | `home/core/exp/sys/base/ripgrep.nix`  | rg binary, --version, pattern search    |
| `home_core_exp_sys_base_eza`      | `home/core/exp/sys/base/eza.nix`      | eza binary, --version, list             |
| `home_core_exp_sys_base_fd`       | `home/core/exp/sys/base/fd.nix`       | fd binary, --version, find files        |
| `home_core_exp_sys_base_jq`       | `home/core/exp/sys/base/jq.nix`       | jq binary, JSON parse, filter           |
| `home_core_exp_sys_base_zoxide`   | `home/core/exp/sys/base/zoxide.nix`   | zoxide binary, --version                |

#### core/exp/sys/shell

| check 名称                     | 文件                               | 验证点                                         |
| ------------------------------ | ---------------------------------- | ---------------------------------------------- |
| `home_core_exp_sys_shell_zsh`  | `home/core/exp/sys/shell/zsh.nix`  | zsh binary, --version, default shell, compinit |
| `home_core_exp_sys_shell_fish` | `home/core/exp/sys/shell/fish.nix` | fish binary, --version, variable, abbr         |

#### core/exp/sys/monitor (NEW)

| check 名称                  | 文件                                    | 验证点                 |
| --------------------------- | --------------------------------------- | ---------------------- |
| `home_core_exp_sys_monitor` | `home/core/exp/sys/monitor/default.nix` | btop, htop, btm binary |

#### core/exp/sys/media (NEW)

| check 名称                | 文件                                  | 验证点             |
| ------------------------- | ------------------------------------- | ------------------ |
| `home_core_exp_sys_media` | `home/core/exp/sys/media/default.nix` | mpv, ffmpeg binary |

#### core/exp/sys/fs (NEW)

| check 名称             | 文件                               | 验证点                          |
| ---------------------- | ---------------------------------- | ------------------------------- |
| `home_core_exp_sys_fs` | `home/core/exp/sys/fs/default.nix` | duf, zip, unzip, tar round-trip |

#### core/exp/sys/misc (NEW)

| check 名称               | 文件                                 | 验证点      |
| ------------------------ | ------------------------------------ | ----------- |
| `home_core_exp_sys_misc` | `home/core/exp/sys/misc/default.nix` | yazi binary |

#### core/sec + core/srv

| check 名称                     | 文件                               | 验证点                            |
| ------------------------------ | ---------------------------------- | --------------------------------- |
| `home_core_sec`                | `home/core/sec/default.nix`        | module parses, VM reaches target  |
| `home_core_srv_notify_mako`    | `home/core/srv/notify/mako.nix`    | mako, makoctl, notify-send binary |
| `home_core_srv_security_gnupg` | `home/core/srv/security/gnupg.nix` | gpg binary, gpg-agent, list-keys  |

#### core/exp/app/editor

| check 名称                      | 文件                                | 验证点                          |
| ------------------------------- | ----------------------------------- | ------------------------------- |
| `home_core_exp_app_editor_nvim` | `home/core/exp/app/editor/nvim.nix` | nvim binary, headless Lua, quit |

#### env/dev

| check 名称                | 文件                                  | 验证点                                 |
| ------------------------- | ------------------------------------- | -------------------------------------- |
| `home_env_dev_c`          | `home/env/dev/c/default.nix`          | gcc, cc, ar, make                      |
| `home_env_dev_cpp`        | `home/env/dev/cpp/default.nix`        | g++, clang, cmake, ninja               |
| `home_env_dev_rust`       | `home/env/dev/rust/default.nix`       | rustc, cargo, --version                |
| `home_env_dev_go`         | `home/env/dev/go/default.nix`         | go binary, GOPATH, hello world compile |
| `home_env_dev_python`     | `home/env/dev/python/default.nix`     | python3, pip, uv, venv creation        |
| `home_env_dev_typescript` | `home/env/dev/typescript/default.nix` | node, npm, tsc                         |
| `home_env_dev_java`       | `home/env/dev/java/default.nix`       | java, javac, --version                 |
| `home_env_dev_lua`        | `home/env/dev/lua/default.nix`        | lua binary, luarocks                   |
| `home_env_dev_zig`        | `home/env/dev/zig/default.nix`        | zig binary, --version                  |
| `home_env_dev_nix`        | `home/env/dev/nix/default.nix`        | nix-prefetch-url, nix-tree             |
| `home_env_dev_re`         | `home/env/dev/re/default.nix`         | ghidra, radare2                        |

---

### 3.4 Lib-Plane

| check 名称                 | 文件                           | 验证点                                   |
| -------------------------- | ------------------------------ | ---------------------------------------- |
| `lib_shared_shared_enum`   | `lib/shared/shared/enum.nix`   | arch/platform/shell/drive-group 枚举语义 |
| `lib_shared_shared_fn`     | `lib/shared/shared/fn.nix`     | isNixOS, homeDir, sopsRuntimePath        |
| `lib_shared_shared_schema` | `lib/shared/shared/schema.nix` | schema 结构, merge 语义, runtime 优先级  |

---

### 3.5 Integration-Plane

| check 名称                  | 文件                            | 验证点                                                          |
| --------------------------- | ------------------------------- | --------------------------------------------------------------- |
| `integration_hm_activation` | `integration/hm_activation.nix` | HM NixOS module wiring, user home, zsh shell, git/direnv/python |

---

### 3.6 nmt-Plane (NEW — 零 VM, 纯 eval)

所有 nmt 测试前缀 `nmt_`，位于 `tests/nmt/` 下，镜像 `home/` 结构。

#### core/base (dotfile 内容)

| check 名称                    | 文件                              | 验证点                                               |
| ----------------------------- | --------------------------------- | ---------------------------------------------------- |
| `nmt_home_core_base_git`      | `nmt/home/core/base/git.nix`      | .config/git/config: user/email/branch/delta          |
| `nmt_home_core_base_starship` | `nmt/home/core/base/starship.nix` | .config/starship.toml: [character], add_newline      |
| `nmt_home_core_base_direnv`   | `nmt/home/core/base/direnv.nix`   | .config/direnv/direnvrc: nix-direnv sourced          |
| `nmt_home_core_base_atuin`    | `nmt/home/core/base/atuin.nix`    | .config/atuin/config.toml: style, sync; systemd unit |
| `nmt_home_core_base_zoxide`   | `nmt/home/core/base/zoxide.nix`   | .zshrc contains zoxide init                          |
| `nmt_home_core_base_tmux`     | `nmt/home/core/base/tmux.nix`     | .config/tmux/tmux.conf: prefix C-a, vi, mouse        |
| `nmt_home_core_base_bat`      | `nmt/home/core/base/bat.nix`      | .config/bat/config: theme TwoDark, style             |

#### core/exp/sys/shell

| check 名称                         | 文件                                   | 验证点                                               |
| ---------------------------------- | -------------------------------------- | ---------------------------------------------------- |
| `nmt_home_core_exp_sys_shell_zsh`  | `nmt/home/core/exp/sys/shell/zsh.nix`  | .zshrc: compinit, history=50000, aliases, no .bashrc |
| `nmt_home_core_exp_sys_shell_fish` | `nmt/home/core/exp/sys/shell/fish.nix` | .config/fish/config.fish: abbr, aliases              |

#### core/srv

| check 名称                | 文件                          | 验证点                                               |
| ------------------------- | ----------------------------- | ---------------------------------------------------- |
| `nmt_home_core_srv_gnupg` | `nmt/home/core/srv/gnupg.nix` | .gnupg/gpg-agent.conf: enable-ssh-support, TTL; unit |
| `nmt_home_core_srv_mako`  | `nmt/home/core/srv/mako.nix`  | .config/mako/config: default-timeout, border-size    |

#### core/exp/app

| check 名称                   | 文件                             | 验证点                            |
| ---------------------------- | -------------------------------- | --------------------------------- |
| `nmt_home_core_exp_app_nvim` | `nmt/home/core/exp/app/nvim.nix` | .nix-profile exists (pkg present) |

#### env/dev

| check 名称                    | 文件                       | 验证点                                |
| ----------------------------- | -------------------------- | ------------------------------------- |
| `nmt_home_env_dev_git_config` | `nmt/home/env/dev/git.nix` | delta pager, core.editor=nvim, branch |

---

## 4. 目录结构

```
tests/
├── default.nix                                   ← 统一注册表 (Plane 0–5)
├── test_calc.nix                                 ← Smoke 基线
│
├── nixos/core/
│   ├── base/
│   │   ├── boot.nix
│   │   ├── i18n.nix
│   │   ├── network.nix
│   │   ├── nix.nix
│   │   ├── sound.nix
│   │   └── user.nix
│   ├── drive/
│   │   ├── amd.nix
│   │   ├── intel.nix
│   │   └── nvidia.nix                            ← NEW
│   ├── sec/
│   │   ├── pam.nix
│   │   ├── polkit.nix
│   │   └── secret/cmd/
│   │       ├── age.nix
│   │       └── sops.nix
│   └── srv/
│       ├── db/
│       │   ├── mongodb.nix
│       │   ├── mysql.nix
│       │   ├── postgresql.nix
│       │   └── redis.nix
│       ├── desktop/
│       │   └── flatpak.nix
│       ├── hardware/                             ← NEW
│       │   ├── bluetooth.nix
│       │   └── printing.nix
│       ├── log/
│       │   └── logrotate.nix
│       └── security/
│           ├── keyring.nix
│           └── ssh.nix
│
├── home/core/
│   ├── base/
│   │   ├── fonts.nix
│   │   ├── i18n.nix
│   │   └── portal.nix
│   ├── sec/
│   │   └── default.nix
│   ├── srv/
│   │   ├── notify/mako.nix
│   │   └── security/gnupg.nix
│   └── exp/
│       ├── app/editor/nvim.nix
│       └── sys/
│           ├── base/
│           │   ├── atuin.nix
│           │   ├── bat.nix
│           │   ├── direnv.nix
│           │   ├── eza.nix
│           │   ├── fd.nix
│           │   ├── fzf.nix
│           │   ├── git.nix
│           │   ├── jq.nix
│           │   ├── ripgrep.nix
│           │   ├── starship.nix
│           │   ├── tmux.nix
│           │   └── zoxide.nix
│           ├── shell/
│           │   ├── fish.nix
│           │   └── zsh.nix
│           ├── monitor/default.nix             ← NEW
│           ├── media/default.nix               ← NEW
│           ├── fs/default.nix                  ← NEW
│           └── misc/default.nix                ← NEW
│
├── home/env/dev/
│   ├── c/default.nix
│   ├── cpp/default.nix
│   ├── go/default.nix
│   ├── java/default.nix
│   ├── lua/default.nix
│   ├── nix/default.nix
│   ├── python/default.nix
│   ├── re/default.nix
│   ├── rust/default.nix
│   ├── typescript/default.nix
│   └── zig/default.nix
│
├── lib/shared/shared/
│   ├── enum.nix
│   ├── fn.nix
│   └── schema.nix
│
├── integration/
│   └── hm_activation.nix
│
└── nmt/                                         ← NEW (Plane 5)
    ├── default.nix
    └── home/
        ├── core/
        │   ├── base/
        │   │   ├── atuin.nix
        │   │   ├── bat.nix
        │   │   ├── direnv.nix
        │   │   ├── git.nix
        │   │   ├── starship.nix
        │   │   ├── tmux.nix
        │   │   └── zoxide.nix
        │   ├── srv/
        │   │   ├── gnupg.nix
        │   │   └── mako.nix
        │   └── exp/
        │       ├── app/nvim.nix
        │       └── sys/shell/
        │           ├── fish.nix
        │           └── zsh.nix
        └── env/dev/
            └── git.nix
```

---

## 5. 运行指南

### 全部测试

```bash
nix flake check
```

### 按平面运行

```bash
# Plane 1: NixOS-Plane only
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 5 n == "nixos") cs)' \
  | tr -d '[]"' | tr ' ' '\n' \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" -L

# Plane 2: HM-Plane only
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "home") cs)' \
  | tr -d '[]"' | tr ' ' '\n' \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" -L

# Plane 5: nmt-Plane only (FAST — no QEMU)
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  | tr -d '[]"' | tr ' ' '\n' \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" -L
```

### 单个测试（详细日志）

```bash
# NixOS-Plane 示例
nix build .#checks.x86_64-linux.nixos_core_srv_db_postgresql -L

# nmt-Plane 示例 (秒级)
nix build .#checks.x86_64-linux.nmt_home_core_base_git -L

# Integration-Plane
nix build .#checks.x86_64-linux.integration_hm_activation -L
```

### 交互式调试 (QEMU VM)

```bash
# 构建驱动
nix build .#checks.x86_64-linux.nixos_core_srv_db_postgresql.driverInteractive
./result/bin/nixos-test-driver

# REPL 内:
start_all()
machine.wait_for_unit("postgresql.service")
machine.succeed("sudo -u postgres psql -c 'SELECT 1;'")
machine.screenshot("debug_pg")
```

### 快速 nmt 调试 (无 VM)

```bash
# eval 断言 (nix repl)
:lf .
outputs.checks.x86_64-linux.nmt_home_core_base_git
```

---

## 6. 设计原则与约束

### 平面纯洁性

| 原则                          | 约束                                        |
| ----------------------------- | ------------------------------------------- |
| NixOS-Plane 不导入 HM 模块    | `nodes.machine` 中无 `home-manager` 选项    |
| HM-Plane 不测试系统服务       | `testScript` 不访问 `systemctl --system`    |
| nmt-Plane 不启动 VM           | 仅使用 `buildHomeManagerTest`，不含 `nodes` |
| Lib-Plane 不启动 systemd 服务 | `virtualisation.memorySize = 256`，minimal  |
| Integration-Plane 有明确目的  | 必须测试跨平面交互，不重复单平面逻辑        |

### 测试命名

```
<plane>_<module-path-underscored>
nixos_core_srv_db_postgresql
home_core_exp_sys_base_git
nmt_home_core_base_git
lib_shared_shared_fn
integration_hm_activation
```

### sops 约束

所有测试不依赖 SOPS secrets（无 age 私钥）。需要 secret 的模块通过 mock 文件替代：

```nix
# mock secret pattern in testScript
machine.succeed("mkdir -p /run/secrets && echo 'mock' > /run/secrets/test_key")
```

---

## 7. 扩展新测试

### 新增 NixOS-Plane 测试

```nix
# 1. 创建测试文件
# tests/nixos/core/srv/new-service.nix
{ pkgs, lib, ... }:
{
  name = "nixos_core_srv_new_service";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    services.new-service.enable = true;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("new-service.service")
    with subtest("new-service: active"):
        st = machine.succeed("systemctl is-active new-service").strip()
        assert st == "active"
  '';
}

# 2. 注册到 tests/default.nix (Plane 1 区块)
nixos_core_srv_new_service = nixosTest ./nixos/core/srv/new-service.nix;
```

### 新增 nmt-Plane 测试

```nix
# 1. 创建测试文件
# tests/nmt/home/core/base/new-tool.nix
{ lib, ... }:
lib.nmt.buildHomeManagerTest {
  description = "new-tool: config file written correctly";
  modules = [{
    home = { username = "testuser"; homeDirectory = "/home/testuser"; stateVersion = "25.11"; };
    programs.new-tool = { enable = true; setting = "value"; };
  }];
  tests = {
    "new-tool: config exists" = { path = ".config/new-tool/config"; exists = true; };
    "new-tool: setting written" = { path = ".config/new-tool/config"; contains = [ "setting = value" ]; };
  };
}

# 2. 注册到 tests/nmt/default.nix
nmt_home_core_base_new_tool = nmtTest ./home/core/base/new-tool.nix;

# 3. 注册到 tests/default.nix (nmtChecks 自动合并)
# 无需修改 — nmtChecks 透传所有 nmt/* 条目
```

---

## 8. CI 集成

### GitHub Actions 阶段映射

```yaml
# .github/workflows/ci.yml

# Stage 1: Lint & Evaluate  →  nix eval checks (no build)
# Stage 2: nmt-Plane         →  nmt_* checks (zero VM, fast)
# Stage 3: Lib-Plane         →  lib_* checks (256 MiB VM)
# Stage 4: Smoke             →  test_calc
# Stage 5: NixOS-Plane       →  nixos_* (requires KVM)
# Stage 6: HM-Plane          →  home_*  (requires KVM)
# Stage 7: Integration       →  integration_* (requires KVM)
```

### nmt CI 步骤 (快速, 无 KVM)

```yaml
- name: nmt checks (HM dotfile, zero VM)
  run: |
    CHECKS=$(nix eval .#checks.x86_64-linux --apply \
      'cs: builtins.attrNames (builtins.filterAttrs (n: _:
        (builtins.substring 0 4 n) == "nmt_") cs)' --json \
      | jq -r '.[]')
    for check in $CHECKS; do
      echo "Running nmt check: $check"
      nix build ".#checks.x86_64-linux.$check" -L --no-link
    done
```

### KVM 依存检查 (NixOS/HM/Integration Planes)

```yaml
- name: Check KVM availability
  run: |
    if [ ! -e /dev/kvm ]; then
      echo "WARNING: /dev/kvm not available — skipping QEMU-based planes"
      echo "SKIP_QEMU=1" >> $GITHUB_ENV
    fi

- name: NixOS-Plane tests
  if: env.SKIP_QEMU != '1'
  run: nix build .#checks.x86_64-linux.nixos_core_base_boot -L --no-link
```
