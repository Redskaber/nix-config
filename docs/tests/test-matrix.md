# NixOS Config — Test Matrix

> `docs/tests/test-matrix.md`
> Updated: 2026-05-09

---

## 目录

1. [架构概述](#1-架构概述)
2. [测试平面划分](#2-测试平面划分)
3. [完整测试矩阵](#3-完整测试矩阵)
   - 3.1 Smoke / Sanity
   - 3.2 NixOS-Plane
   - 3.3 Home-Manager-Plane
   - 3.4 Lib-Plane
   - 3.5 Integration-Plane
4. [目录结构](#4-目录结构)
5. [运行指南](#5-运行指南)
6. [设计原则与约束](#6-设计原则与约束)
7. [扩展新测试](#7-扩展新测试)
8. [CI 集成](#8-ci-集成)

---

## 1. 架构概述

```
tests/
├── default.nix              ← 注册表: 所有平面 checks 汇总
├── test_calc.nix            ← Smoke 基线 (保留原始)
│
├── nixos/                   ← NixOS-Plane (QEMU VM)
│   └── core/
│       ├── base/            ← boot, user, network, i18n, nix, sound
│       ├── sec/             ← polkit, pam, secret_tools
│       └── srv/
│           ├── db/          ← postgresql, mysql, redis, mongodb
│           ├── security/    ← ssh, keyring
│           ├── log/         ← logrotate
│           └── desktop/     ← flatpak
│
├── home/                    ← Home-Manager-Plane (VM + HM module)
│   ├── _lib/                ← 共享 HM 节点辅助模块
│   └── core/
│       ├── base/            ← fonts, i18n, portal
│       ├── sec/             ← gnupg
│       ├── srv/             ← mako
│       └── exp/
│           ├── sys/         ← zsh, fish, git, direnv, starship, atuin, tmux
│           └── app/         ← nvim
│   └── env/dev/             ← nix, rust, python, typescript, go
│
├── lib/                     ← Lib-Plane (pure Nix eval, minimal VM)
│   ├── test_enum.nix
│   ├── test_fn.nix
│   └── test_schema.nix
│
└── integration/             ← Integration-Plane (NixOS + HM 联合)
    └── test_hm_activation.nix
```

---

## 2. 测试平面划分

| 平面                   | runner                   | VM?              | 关注点                    | 典型时长 |
| ---------------------- | ------------------------ | ---------------- | ------------------------- | -------- |
| **Smoke**              | `runNixOSTest`           | QEMU             | 基本系统完整性            | ~1 min   |
| **NixOS-Plane**        | `runNixOSTest`           | QEMU             | `nixos/*` 模块 + 系统服务 | 2–10 min |
| **Home-Manager-Plane** | `runNixOSTest`           | QEMU + HM module | `home/*` 模块 + 用户环境  | 2–8 min  |
| **Lib-Plane**          | `runNixOSTest` (minimal) | QEMU (256 MiB)   | `lib/shared` 纯表达式     | <1 min   |
| **Integration-Plane**  | `runNixOSTest`           | QEMU (full)      | NixOS + HM 联合激活       | 5–15 min |

### 平面隔离规则

- **NixOS-Plane** 不导入任何 `home-manager` 模块
- **Home-Manager-Plane** 不测试系统服务(sshd, postgresql, …)
- **Lib-Plane** 不启动任何 systemd 服务; `nix-instantiate` 足够
- **Integration-Plane** 可导入两个平面的模块，但必须有明确的集成目的

---

## 3. 完整测试矩阵

### 3.1 Smoke / Sanity

| check 名称  | 文件                  | 验证点                    |
| ----------- | --------------------- | ------------------------- |
| `test_calc` | `tests/test_calc.nix` | 基础 VM 启动 + shell 计算 |

### 3.2 NixOS-Plane

#### core/base

| check 名称           | 文件                               | 验证点                                               |
| -------------------- | ---------------------------------- | ---------------------------------------------------- |
| `nixos_base_boot`    | `nixos/core/base/test_boot.nix`    | multi-user.target, PID1=systemd, 内核版本            |
| `nixos_base_user`    | `nixos/core/base/test_user.nix`    | 用户存在, 默认 shell=zsh, 附加组, mutableUsers=false |
| `nixos_base_network` | `nixos/core/base/test_network.nix` | hostname, NetworkManager, 防火墙, IPv6               |
| `nixos_base_i18n`    | `nixos/core/base/test_i18n.nix`    | LANG=en_US.UTF-8, zh_CN locale, Asia/Shanghai TZ     |
| `nixos_base_nix`     | `nixos/core/base/test_nix.nix`     | nix-daemon, flakes, auto-optimise-store              |
| `nixos_base_sound`   | `nixos/core/base/test_sound.nix`   | PipeWire 服务, rtkit, pamixer 二进制                 |

#### core/sec

| check 名称               | 文件                                   | 验证点                               |
| ------------------------ | -------------------------------------- | ------------------------------------ |
| `nixos_sec_polkit`       | `nixos/core/sec/test_polkit.nix`       | polkit.service, pkaction, rules.d    |
| `nixos_sec_pam`          | `nixos/core/sec/test_pam.nix`          | PAM 配置文件存在, 用户可创建         |
| `nixos_sec_secret_tools` | `nixos/core/sec/test_secret_tools.nix` | age 生成/加密, sops 版本, ssh-to-age |

#### core/srv/security

| check 名称                   | 文件                                       | 验证点                                        |
| ---------------------------- | ------------------------------------------ | --------------------------------------------- |
| `nixos_srv_security_ssh`     | `nixos/core/srv/security/test_ssh.nix`     | sshd 监听 :22, PasswordAuth=no, PermitRoot=no |
| `nixos_srv_security_keyring` | `nixos/core/srv/security/test_keyring.nix` | gnome-keyring-daemon, secret-tool             |

#### core/srv/db

| check 名称                | 文件                                    | 验证点                                                           |
| ------------------------- | --------------------------------------- | ---------------------------------------------------------------- |
| `nixos_srv_db_postgresql` | `nixos/core/srv/db/test_postgresql.nix` | service active, :5432, peer auth, ensureDB/User, health_check 表 |
| `nixos_srv_db_mysql`      | `nixos/core/srv/db/test_mysql.nix`      | service active, socket auth, ensureDB/User, health_check         |
| `nixos_srv_db_redis`      | `nixos/core/srv/db/test_redis.nix`      | service active, PING/PONG, SET/GET/DEL, bind=127.0.0.1           |
| `nixos_srv_db_mongodb`    | `nixos/core/srv/db/test_mongodb.nix`    | service active, :27017, mongosh ping, insert/find                |

#### core/srv/log + desktop

| check 名称                  | 文件                                      | 验证点                       |
| --------------------------- | ----------------------------------------- | ---------------------------- |
| `nixos_srv_log_logrotate`   | `nixos/core/srv/log/test_logrotate.nix`   | 二进制, 配置合法, timer 单元 |
| `nixos_srv_desktop_flatpak` | `nixos/core/srv/desktop/test_flatpak.nix` | flatpak 版本, remote-list    |

### 3.3 Home-Manager-Plane

#### core/base

| check 名称         | 文件                             | 验证点                              |
| ------------------ | -------------------------------- | ----------------------------------- |
| `home_base_fonts`  | `home/core/base/test_fonts.nix`  | fc-list, Noto fonts, fc-cache       |
| `home_base_i18n`   | `home/core/base/test_i18n.nix`   | LANG, zh_CN locale, fcitx5          |
| `home_base_portal` | `home/core/base/test_portal.nix` | xdg-desktop-portal 二进制, 配置目录 |

#### core/sec & srv

| check 名称       | 文件                           | 验证点                         |
| ---------------- | ------------------------------ | ------------------------------ |
| `home_sec_gnupg` | `home/core/sec/test_gnupg.nix` | gpg 版本, gpg-agent, list-keys |
| `home_srv_mako`  | `home/core/srv/test_mako.nix`  | mako 二进制, makoctl, 版本     |

#### core/exp/sys — Shell & Tools

| check 名称                | 文件                                  | 验证点                         |
| ------------------------- | ------------------------------------- | ------------------------------ |
| `home_exp_sys_shell_zsh`  | `home/core/exp/sys/test_zsh.nix`      | 二进制, 版本, 执行, 默认 shell |
| `home_exp_sys_shell_fish` | `home/core/exp/sys/test_fish.nix`     | 二进制, 版本, 执行             |
| `home_exp_sys_git`        | `home/core/exp/sys/test_git.nix`      | 版本, init+commit 流程         |
| `home_exp_sys_direnv`     | `home/core/exp/sys/test_direnv.nix`   | 版本, allow+exec 环境注入      |
| `home_exp_sys_starship`   | `home/core/exp/sys/test_starship.nix` | 版本, prompt 渲染              |
| `home_exp_sys_atuin`      | `home/core/exp/sys/test_atuin.nix`    | 版本, init 输出                |
| `home_exp_sys_tmux`       | `home/core/exp/sys/test_tmux.nix`     | 版本, 会话创建/销毁            |

#### core/exp/app

| check 名称                 | 文件                              | 验证点                              |
| -------------------------- | --------------------------------- | ----------------------------------- |
| `home_exp_app_editor_nvim` | `home/core/exp/app/test_nvim.nix` | 版本, headless Lua exec, write-quit |

#### env/dev

| check 名称                | 文件                                   | 验证点                                           |
| ------------------------- | -------------------------------------- | ------------------------------------------------ |
| `home_env_dev_nix`        | `home/env/dev/test_nix_env.nix`        | nixfmt, nil LSP, nix-tree, eval 1+1              |
| `home_env_dev_rust`       | `home/env/dev/test_rust_env.nix`       | rustc/cargo 版本, rust-analyzer, cargo new+build |
| `home_env_dev_python`     | `home/env/dev/test_python_env.nix`     | python3, uv, pyright, script exec                |
| `home_env_dev_typescript` | `home/env/dev/test_typescript_env.nix` | node/npm/tsc/ts-ls, tsx exec                     |
| `home_env_dev_go`         | `home/env/dev/test_go_env.nix`         | go version, gopls, go run                        |

### 3.4 Lib-Plane

| check 名称          | 文件                  | 验证点                            |
| ------------------- | --------------------- | --------------------------------- |
| `lib_shared_enum`   | `lib/test_enum.nix`   | arch/shell 枚举求值               |
| `lib_shared_fn`     | `lib/test_fn.nix`     | isNixOS, homeDir, sopsRuntimePath |
| `lib_shared_schema` | `lib/test_schema.nix` | 有效 attrset 验证, merge 语义     |

### 3.5 Integration-Plane

| check 名称                        | 文件                                 | 验证点                                  |
| --------------------------------- | ------------------------------------ | --------------------------------------- |
| `integration_nixos_hm_activation` | `integration/test_hm_activation.nix` | HM 激活, 用户 shell, git/ripgrep/direnv |

---

## 4. 目录结构

```
tests/
├── default.nix                          ← 统一注册表 (data-driven)
├── test_calc.nix                        ← smoke (保留)
│
├── nixos/core/
│   ├── base/
│   │   ├── test_boot.nix
│   │   ├── test_user.nix
│   │   ├── test_network.nix
│   │   ├── test_i18n.nix
│   │   ├── test_nix.nix
│   │   └── test_sound.nix
│   ├── sec/
│   │   ├── test_polkit.nix
│   │   ├── test_pam.nix
│   │   └── test_secret_tools.nix
│   └── srv/
│       ├── db/
│       │   ├── test_postgresql.nix
│       │   ├── test_mysql.nix
│       │   ├── test_redis.nix
│       │   └── test_mongodb.nix
│       ├── security/
│       │   ├── test_ssh.nix
│       │   └── test_keyring.nix
│       ├── log/
│       │   └── test_logrotate.nix
│       └── desktop/
│           └── test_flatpak.nix
│
├── home/
│   ├── _lib/
│   │   └── hm_node.nix                  ← 共享 HM 节点模板
│   └── core/
│       ├── base/
│       │   ├── test_fonts.nix
│       │   ├── test_i18n.nix
│       │   └── test_portal.nix
│       ├── sec/
│       │   └── test_gnupg.nix
│       ├── srv/
│       │   └── test_mako.nix
│       └── exp/
│           ├── sys/
│           │   ├── test_zsh.nix
│           │   ├── test_fish.nix
│           │   ├── test_git.nix
│           │   ├── test_direnv.nix
│           │   ├── test_starship.nix
│           │   ├── test_atuin.nix
│           │   └── test_tmux.nix
│           └── app/
│               └── test_nvim.nix
│   └── env/dev/
│       ├── test_nix_env.nix
│       ├── test_rust_env.nix
│       ├── test_python_env.nix
│       ├── test_typescript_env.nix
│       └── test_go_env.nix
│
├── lib/
│   ├── test_enum.nix
│   ├── test_fn.nix
│   └── test_schema.nix
│
└── integration/
    └── test_hm_activation.nix
```

---

## 5. 运行指南

### 全部测试

```bash
nix flake check
```

### 单个测试（详细日志）

```bash
# NixOS-Plane 示例
nix build .#checks.x86_64-linux.nixos_srv_db_postgresql -L

# Home-Manager-Plane 示例
nix build .#checks.x86_64-linux.home_env_dev_rust -L

# Lib-Plane 示例
nix build .#checks.x86_64-linux.lib_shared_fn -L
```

### 交互式调试

```bash
# 构建驱动
nix build .#checks.x86_64-linux.nixos_srv_db_postgresql.driverInteractive
# 进入 REPL
./result/bin/nixos-test-driver

# REPL 内:
# start_all()
# machine.wait_for_unit("postgresql.service")
# machine.succeed("sudo -u postgres psql -c 'SELECT 1;'")
# machine.screenshot("debug_pg")
```

### 按平面批量运行

```bash
# 仅 NixOS-Plane
nix flake check --no-build \
  $(nix eval .#checks.x86_64-linux --apply 'cs: builtins.attrNames cs' \
    | tr -d '[]"' | tr ' ' '\n' | grep '^nixos_' | \
    xargs -I{} echo ".#checks.x86_64-linux.{}")
```

---

## 6. 设计原则与约束

| 原则                    | 实现                                                                  |
| ----------------------- | --------------------------------------------------------------------- |
| **依赖倒置**            | `hm_node.nix` 接受 `hmModules` 注入; `default.nix` 只持有引用         |
| **边界明确**            | NixOS/HM/Lib/Integration 四平面不跨界导入                             |
| **数据驱动**            | `default.nix` 是纯 attr-set 声明; runner 统一注入                     |
| **生命周期分离**        | sops 运行时解密不在单元测试中; 属于 integration 阶段                  |
| **generate-not-mutate** | 无 sed/in-place; 测试节点配置均为声明式                               |
| **无持久状态**          | 每个 VM 都是无状态的; 依赖 `initialScript`/`ensureUsers` 的幂等初始化 |
| **增量模式**            | 可按 check 名称前缀筛选运行; 新测试只需加入 `default.nix`             |

### 禁止行为

- 测试文件中 **不能** 直接 `import ../../../nixos/core/...`（破坏平面隔离）
- 测试节点 **不能** 在 `testScript` 里运行 `nixos-rebuild`（非测试关注点）
- NixOS-Plane 测试 **不能** 依赖真实的 sops 密钥文件
- Lib-Plane 测试 **不应** 启动任何 systemd 服务

---

## 7. 扩展新测试

### 步骤 1：选择平面

```
nixos/* → 系统服务、内核功能、守护进程
home/*  → 用户环境、dotfiles、CLI 工具
lib/*   → 纯 Nix 表达式、schema、函数
integration/* → 跨平面联动
```

### 步骤 2：创建测试文件

模板（NixOS-Plane）：

```nix
# tests/nixos/core/srv/db/test_newservice.nix
{ pkgs, lib, ... }:
{
  name = "nixos_srv_db_newservice";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    services.newservice.enable = true;
    environment.systemPackages = with pkgs; [ newservice-cli ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("newservice.service")

    with subtest("newservice: active"):
        assert machine.succeed("systemctl is-active newservice").strip() == "active"
  '';
}
```

### 步骤 3：注册到 default.nix

```nix
# tests/default.nix — nixosTests 块末尾添加
nixos_srv_db_newservice = nixosTest ./nixos/core/srv/db/test_newservice.nix;
```

### 步骤 4：验证

```bash
nix build .#checks.x86_64-linux.nixos_srv_db_newservice -L
```

---

## 8. CI 集成

### GitHub Actions 示例

```yaml
# .github/workflows/tests.yml
name: NixOS Config Tests
on: [push, pull_request]

jobs:
  flake-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v27
        with:
          extra_nix_config: |
            experimental-features = nix-command flakes
            accept-flake-config = true
      - uses: cachix/cachix-action@v15
        with:
          name: nix-config
          authToken: "${{ secrets.CACHIX_AUTH_TOKEN }}"
      - name: Run smoke tests
        run: nix build .#checks.x86_64-linux.test_calc -L
      - name: Run NixOS base tests
        run: |
          nix build .#checks.x86_64-linux.nixos_base_boot -L
          nix build .#checks.x86_64-linux.nixos_base_user -L
          nix build .#checks.x86_64-linux.nixos_base_network -L
      - name: Run lib tests
        run: nix flake check --no-build 2>/dev/null || true
```

### 推荐 CI 策略

| 触发          | 执行范围                                    | 耗时目标 |
| ------------- | ------------------------------------------- | -------- |
| PR (draft)    | smoke + lib                                 | < 3 min  |
| PR (ready)    | smoke + lib + nixos*base*_ + home*exp_sys*_ | < 15 min |
| merge to main | 全部 checks                                 | < 45 min |
| nightly       | 全部 checks + integration                   | < 60 min |

---

_文档由 `tests/` 目录设计同步维护。每次向 `default.nix` 添加新条目时请同步更新本文档的矩阵表格。_
