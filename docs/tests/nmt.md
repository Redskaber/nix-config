# nmt — NixOS Module Tests (Home-Manager Plane)

> `docs/tests/nmt.md`
> Updated: 2026-05-09

---

## 目录

1. [nmt 简介](#1-nmt-简介)
2. [nmt vs nixosTest — 技术选型对照](#2-nmt-vs-nixostest--技术选型对照)
3. [nmt 核心概念与结构](#3-nmt-核心概念与结构)
   - 3.1 测试模块组成
   - 3.2 `setup` 块：注入 HM 配置
   - 3.3 `test` 块：断言文件系统状态
   - 3.4 完整 API 速查表
4. [在 nix-config 中的位置与使用方式](#4-在-nix-config-中的位置与使用方式)
   - 4.1 flake.nix 集成
   - 4.2 nmt runner 封装
   - 4.3 与 nixosTest HM-Plane 的互补关系
5. [nmt 测试矩阵（HM-Plane 纯模块断言）](#5-nmt-测试矩阵hm-plane-纯模块断言)
   - 5.1 core/base
   - 5.2 core/sec
   - 5.3 core/srv
   - 5.4 core/exp/sys
   - 5.5 core/exp/app
   - 5.6 env/dev
6. [目录结构](#6-目录结构)
7. [编写 nmt 测试：完整示例](#7-编写-nmt-测试完整示例)
   - 7.1 基础文件断言
   - 7.2 JSON/TOML 内容断言
   - 7.3 systemd unit 断言
   - 7.4 负向断言（文件不存在）
8. [运行指南](#8-运行指南)
9. [调试技巧](#9-调试技巧)
10. [设计原则与约束](#10-设计原则与约束)
11. [扩展新 nmt 测试](#11-扩展新-nmt-测试)
12. [常见错误与解决方案](#12-常见错误与解决方案)
13. [nmt vs nixosTest 决策树](#13-nmt-vs-nixostest-决策树)

---

## 1. nmt 简介

**nmt（NixOS Module Tests）** 是专为 [home-manager](https://github.com/nix-community/home-manager) 模块设计的轻量级测试框架。它由 home-manager 项目维护，核心思路是：

> 不启动虚拟机，直接对 home-manager 激活后产生的**文件系统快照**进行断言。

```
HM 模块配置
    │
    ▼  home-manager build (nix eval)
文件系统树（/home/<user>/ 的声明式快照）
    │
    ▼  nmt 断言引擎
断言：文件存在 / 内容匹配 / JSON 字段 / systemd unit
```

### 关键特性

| 特性           | 描述                                         |
| -------------- | -------------------------------------------- |
| **零 VM 开销** | 纯 Nix eval，不启动 QEMU，秒级完成           |
| **确定性**     | 断言的是声明式配置输出，不依赖运行时状态     |
| **内容感知**   | 支持 JSON、INI、TOML、纯文本的结构化断言     |
| **HM 原生**    | 与 HM 模块系统深度集成，直接使用 HM 选项语法 |
| **增量友好**   | 每个模块一个测试文件，可独立运行             |

---

## 2. nmt vs nixosTest — 技术选型对照

| 维度                 | **nmt**                              | **nixosTest (runNixOSTest)**         |
| -------------------- | ------------------------------------ | ------------------------------------ |
| **执行环境**         | 纯 Nix eval（无 VM）                 | QEMU 虚拟机                          |
| **速度**             | 秒级（< 10 s）                       | 分钟级（1–10 min）                   |
| **测试粒度**         | 单模块 / 单选项                      | 系统服务 / 进程 / 网络 / 运行时行为  |
| **断言目标**         | 文件路径、内容、JSON 字段            | 服务状态、端口、命令输出             |
| **适合 HM 哪类测试** | dotfile 内容、程序选项输出、配置格式 | 服务激活、运行时进程（如 gpg-agent） |
| **sops 解密**        | 不支持（无运行时）                   | 通过 mock secret 文件支持            |
| **CI 成本**          | 极低                                 | 高（需要 KVM / QEMU）                |
| **调试体验**         | `nix-instantiate --eval` 即可        | `nixos-test-driver` 交互式           |

### 选择原则

```
HM 模块测试问题
        │
        ├─ 问：只需验证文件存在/内容正确？
        │       → 选 nmt
        │
        ├─ 问：需要验证守护进程启动 / socket / 运行时行为？
        │       → 选 nixosTest (HM-Plane)
        │
        └─ 问：需要 NixOS + HM 联合激活验证？
                → 选 nixosTest (Integration-Plane)
```

---

## 3. nmt 核心概念与结构

### 3.1 测试模块组成

nmt 测试是一个标准 Nix 函数，输出一个 attrset：

```nix
# tests/nmt/home/core/exp/sys/base/git.nix
{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  # 描述此测试（用于错误输出）
  description = "git: config files written correctly";

  # 注入的 HM 模块配置（等价于 home-manager 用户配置块）
  modules = [
    {
      programs.git = {
        enable    = true;
        userName  = "Test User";
        userEmail = "test@example.com";
        extraConfig.init.defaultBranch = "main";
      };
    }
  ];

  # 断言序列（有序执行）
  tests = {
    "git: .gitconfig exists" = {
      path    = ".config/git/config";    # 相对 $HOME
      exists  = true;
    };

    "git: user.name written" = {
      path    = ".config/git/config";
      contains = [ "[user]" "name = Test User" ];
    };

    "git: defaultBranch = main" = {
      path    = ".config/git/config";
      contains = [ "defaultBranch = main" ];
    };
  };
}
```

### 3.2 `modules` 块：注入 HM 配置

`modules` 是一个 NixOS 模块列表，直接使用 HM 选项语法：

```nix
modules = [
  # 来自 flake 的 HM 模块（可选）
  inputs.home-manager.homeManagerModules.default

  # 内联配置
  {
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };
    programs.zsh.enable = true;
  }

  # 指向本项目的 HM 模块（路径注入）
  ../../home/core/exp/sys/shell/zsh.nix
];
```

### 3.3 `tests` 块：断言文件系统状态

所有路径均相对于 `$HOME`（`/home/<username>/`）：

```nix
tests = {
  # 文件存在性
  "file exists" = {
    path   = ".zshrc";
    exists = true;
  };

  # 文件不存在
  "file absent" = {
    path   = ".bash_profile";
    exists = false;
  };

  # 纯文本包含
  "content match" = {
    path     = ".zshrc";
    contains = [ "autoload -U compinit" ];
  };

  # JSON 字段断言
  "json field" = {
    path = ".config/starship.toml";   # TOML 视为文本
    contains = [ "[character]" ];
  };

  # 路径是符号链接
  "is symlink" = {
    path      = ".config/nvim/init.lua";
    isSymlink = true;
  };
};
```

### 3.4 完整 API 速查表

| 断言字段      | 类型       | 描述                           |
| ------------- | ---------- | ------------------------------ |
| `path`        | `string`   | 相对 `$HOME` 的路径（必填）    |
| `exists`      | `bool`     | 文件/目录存在性                |
| `contains`    | `[string]` | 所有字符串必须出现在文件内容中 |
| `notContains` | `[string]` | 所有字符串不得出现在文件内容中 |
| `isSymlink`   | `bool`     | 是否为符号链接                 |
| `isDirectory` | `bool`     | 是否为目录                     |
| `hasMode`     | `string`   | 文件权限（如 `"0644"`）        |
| `matchesPCRE` | `string`   | Perl 兼容正则表达式            |

---

## 4. 在 nix-config 中的位置与使用方式

### 4.1 flake.nix 集成

```nix
# flake.nix (checks 输出段)
checks.${system} =
  # … 已有的 nixosTest checks …
  //
  # nmt checks（HM 纯模块断言）
  (import ./tests/nmt/default.nix {
    inherit inputs;
    pkgs = nixpkgs.legacyPackages.${system};
    hmLib = home-manager.lib;
  });
```

### 4.2 nmt runner 封装

```nix
# tests/nmt/default.nix
{ inputs, pkgs, hmLib, ... }:
let
  nmtTest = path: hmLib.buildHomeManagerTest {
    inherit pkgs;
    modules  = [ path ];
    _module.args = { inherit inputs; };
  };
in {
  # nmt checks（前缀 nmt_ 与 nixosTest checks 区分）
  nmt_home_core_base_git_config    = nmtTest ./home/core/exp/sys/base/git.nix;
  nmt_home_core_base_zsh_config    = nmtTest ./home/core/exp/sys/shell/zsh.nix;
  nmt_home_core_base_starship_toml = nmtTest ./home/core/exp/sys/base/starship.nix;
  # …
}
```

### 4.3 与 nixosTest HM-Plane 的互补关系

```
home/core/exp/sys/base/git.nix
        │
        ├─ nmt_home_core_base_git_config    ← 断言 .config/git/config 内容
        │    (tests/nmt/home/…/git.nix)          纯 eval，零 VM
        │
        └─ home_core_exp_sys_base_git       ← 断言 git 二进制可执行、commit 流程
             (tests/home/core/…/git.nix)         QEMU VM，运行时验证
```

两者不重复覆盖：nmt 验证**配置文件内容正确**，nixosTest 验证**二进制可运行且行为正确**。

---

## 5. nmt 测试矩阵（HM-Plane 纯模块断言）

所有 nmt 测试前缀为 `nmt_`，路径在 `tests/nmt/` 下（镜像 `home/` 结构）。

### 5.1 core/base

| check 名称                  | 文件                            | 验证点                                         |
| --------------------------- | ------------------------------- | ---------------------------------------------- |
| `nmt_home_core_base_fonts`  | `nmt/home/core/base/fonts.nix`  | fontconfig 配置目录存在，hinting 选项写入      |
| `nmt_home_core_base_i18n`   | `nmt/home/core/base/i18n.nix`   | locale 环境变量在 profile 中，sessionVariables |
| `nmt_home_core_base_portal` | `nmt/home/core/base/portal.nix` | portal 配置文件路径存在（非 NixOS 平台）       |

### 5.2 core/sec

| check 名称                | 文件                          | 验证点                                       |
| ------------------------- | ----------------------------- | -------------------------------------------- |
| `nmt_home_core_sec_gnupg` | `nmt/home/core/sec/gnupg.nix` | `gpg-agent.conf` 存在，enable-ssh-support 行 |

### 5.3 core/srv

| check 名称               | 文件                         | 验证点                                          |
| ------------------------ | ---------------------------- | ----------------------------------------------- |
| `nmt_home_core_srv_mako` | `nmt/home/core/srv/mako.nix` | `mako/config` 存在，max-visible / border-radius |

### 5.4 core/exp/sys

| check 名称                       | 文件                                      | 验证点                                                 |
| -------------------------------- | ----------------------------------------- | ------------------------------------------------------ |
| `nmt_home_core_exp_sys_zsh`      | `nmt/home/core/exp/sys/shell/zsh.nix`     | `.zshrc` 存在，`compinit`/`autosuggestion` 行          |
| `nmt_home_core_exp_sys_fish`     | `nmt/home/core/exp/sys/shell/fish.nix`    | `config.fish` 存在，`fish_greeting` 清空               |
| `nmt_home_core_exp_sys_git`      | `nmt/home/core/exp/sys/base/git.nix`      | `.config/git/config`，`[user]` + `defaultBranch`       |
| `nmt_home_core_exp_sys_direnv`   | `nmt/home/core/exp/sys/base/direnv.nix`   | `.config/direnv/direnvrc` 存在，`nix-direnv` source 行 |
| `nmt_home_core_exp_sys_starship` | `nmt/home/core/exp/sys/base/starship.nix` | `.config/starship.toml` 存在，`[character]` 节         |
| `nmt_home_core_exp_sys_atuin`    | `nmt/home/core/exp/sys/base/atuin.nix`    | `.config/atuin/config.toml`，`auto_sync` 字段          |
| `nmt_home_core_exp_sys_tmux`     | `nmt/home/core/exp/sys/base/tmux.nix`     | `.config/tmux/tmux.conf`，prefix key 配置行            |
| `nmt_home_core_exp_sys_bat`      | `nmt/home/core/exp/sys/base/bat.nix`      | `.config/bat/config`，`--theme` 行                     |
| `nmt_home_core_exp_sys_ripgrep`  | `nmt/home/core/exp/sys/base/ripgrep.nix`  | `.config/ripgrep/ripgreprc` 存在（若有 config）        |
| `nmt_home_core_exp_sys_zoxide`   | `nmt/home/core/exp/sys/base/zoxide.nix`   | zsh 集成 init 行写入 `.zshrc`                          |
| `nmt_home_core_exp_sys_fzf`      | `nmt/home/core/exp/sys/base/fzf.nix`      | fzf shell 集成写入 `.zshrc` / `config.fish`            |

### 5.5 core/exp/app

| check 名称                   | 文件                             | 验证点                                  |
| ---------------------------- | -------------------------------- | --------------------------------------- |
| `nmt_home_core_exp_app_nvim` | `nmt/home/core/exp/app/nvim.nix` | `.config/nvim/` 目录存在，init 文件路径 |

### 5.6 env/dev

| check 名称                    | 文件                              | 验证点                                               |
| ----------------------------- | --------------------------------- | ---------------------------------------------------- |
| `nmt_home_env_dev_git_config` | `nmt/home/env/dev/git_config.nix` | dev-git extraConfig 写入（delta pager, branch sort） |

---

## 6. 目录结构

```
tests/nmt/
├── default.nix                          ← nmt 注册表
│
├── home/
│   └── core/
│       ├── base/
│       │   ├── fonts.nix
│       │   ├── i18n.nix
│       │   └── portal.nix
│       ├── sec/
│       │   └── gnupg.nix
│       ├── srv/
│       │   └── mako.nix
│       └── exp/
│           ├── sys/
│           │   ├── shell/
│           │   │   ├── zsh.nix
│           │   │   └── fish.nix
│           │   └── base/
│           │       ├── git.nix
│           │       ├── direnv.nix
│           │       ├── starship.nix
│           │       ├── atuin.nix
│           │       ├── tmux.nix
│           │       ├── bat.nix
│           │       ├── ripgrep.nix
│           │       ├── zoxide.nix
│           │       └── fzf.nix
│           └── app/
│               └── nvim.nix
│
└── _lib/
    └── base_user.nix                    ← 共享用户基础配置模块
```

---

## 7. 编写 nmt 测试：完整示例

### 7.1 基础文件断言

```nix
# tests/nmt/home/core/exp/sys/base/git.nix
{ lib, inputs, ... }:

lib.nmt.buildHomeManagerTest {
  description = "git: config file content";

  modules = [
    {
      home = {
        username      = "testuser";
        homeDirectory = "/home/testuser";
        stateVersion  = "25.11";
      };

      programs.git = {
        enable    = true;
        userName  = "redskaber";
        userEmail = "redskaber@foxmail.com";
        delta.enable = true;
        extraConfig = {
          init.defaultBranch = "main";
          pull.rebase         = true;
        };
      };
    }
  ];

  tests = {
    "git config exists" = {
      path   = ".config/git/config";
      exists = true;
    };

    "git user.name set" = {
      path     = ".config/git/config";
      contains = [ "name = redskaber" ];
    };

    "git user.email set" = {
      path     = ".config/git/config";
      contains = [ "email = redskaber@foxmail.com" ];
    };

    "git defaultBranch = main" = {
      path     = ".config/git/config";
      contains = [ "defaultBranch = main" ];
    };

    "git delta pager configured" = {
      path     = ".config/git/config";
      contains = [ "[delta]" ];
    };
  };
}
```

### 7.2 JSON/TOML 内容断言

```nix
# tests/nmt/home/core/exp/sys/base/starship.nix
{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "starship: TOML config written";

  modules = [{
    home = {
      username = "testuser"; homeDirectory = "/home/testuser";
      stateVersion = "25.11";
    };
    programs.starship = {
      enable = true;
      settings = {
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol   = "[✗](bold red)";
        };
        git_branch.symbol = " ";
      };
    };
  }];

  tests = {
    "starship.toml exists" = {
      path   = ".config/starship.toml";
      exists = true;
    };

    "starship character section" = {
      path     = ".config/starship.toml";
      contains = [ "[character]" ];
    };

    "starship success_symbol" = {
      path     = ".config/starship.toml";
      contains = [ "success_symbol" ];
    };
  };
}
```

### 7.3 systemd unit 断言

```nix
# tests/nmt/home/core/exp/sys/base/atuin.nix
{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "atuin: config + systemd user service";

  modules = [{
    home = {
      username = "testuser"; homeDirectory = "/home/testuser";
      stateVersion = "25.11";
    };
    programs.atuin = {
      enable              = true;
      enableZshIntegration = true;
      settings = {
        auto_sync = false;
        sync_frequency = "5m";
        style = "compact";
      };
    };
  }];

  tests = {
    "atuin config.toml exists" = {
      path   = ".config/atuin/config.toml";
      exists = true;
    };

    "atuin style = compact" = {
      path     = ".config/atuin/config.toml";
      contains = [ "style" ];
    };

    "atuin systemd service unit exists" = {
      path   = ".config/systemd/user/atuin.service";
      exists = true;
    };
  };
}
```

### 7.4 负向断言（文件不存在）

```nix
tests = {
  "bash_profile absent (using zsh)" = {
    path   = ".bash_profile";
    exists = false;
  };

  "no plain-text password in gitconfig" = {
    path        = ".config/git/config";
    notContains = [ "password" "secret" ];
  };
};
```

---

## 8. 运行指南

### 全部 nmt checks

```bash
nix flake check
# nmt checks 前缀为 nmt_，与 nixosTest checks 区分
```

### 单个 nmt check

```bash
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_git -L
```

### 仅运行 nmt 平面

```bash
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)'
# 输出所有 nmt_* check 名称

# 批量构建
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  | tr -d '[]"' | tr ' ' '\n' \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" -L
```

### 快速调试（纯 eval，无构建）

```nix
# 在 nix repl 中：
:lf .
# 检查配置输出
outputs.checks.x86_64-linux.nmt_home_core_exp_sys_git
```

```bash
# 直接 eval 断言目标路径
nix-instantiate --eval -E '
  let
    pkgs = import <nixpkgs> {};
    hm = builtins.getFlake "github:nix-community/home-manager";
    result = hm.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [{ programs.git.enable = true; home.username = "u"; home.homeDirectory = "/home/u"; home.stateVersion = "25.11"; }];
    };
  in result.activationPackage
'
```

---

## 9. 调试技巧

### 查看 HM 激活输出

```bash
# 构建 HM 激活包（不启动 VM）
nix build '.#checks.x86_64-linux.nmt_home_core_exp_sys_git' -L
# 查看输出目录（仅 eval 阶段产物）
ls -la ./result/
```

### 检查生成的配置文件

```bash
# 通过 home-manager build 直接查看配置快照
nix build '.#homeConfigurations."testuser@nixos".activationPackage' --dry-run
```

### 提取 testScript 调试

```bash
# nmt 内部使用 bash 脚本断言
cat $(nix build '.#checks.x86_64-linux.nmt_home_core_exp_sys_git' --no-link --print-out-paths)/bin/run-tests
```

---

## 10. 设计原则与约束

| 原则                    | 实现                                                                |
| ----------------------- | ------------------------------------------------------------------- |
| **依赖倒置**            | `_lib/base_user.nix` 提供最小 home 配置；各测试只注入测试关注的模块 |
| **边界明确**            | nmt 只断言文件系统状态；不启动进程、不测试网络                      |
| **数据驱动**            | `default.nix` 是纯 attr-set；路径与 home/ 目录镜像                  |
| **generate-not-mutate** | 测试配置均为声明式 HM 选项；无 sed/heredoc 变异                     |
| **无持久状态**          | 每次 eval 均从零开始；不依赖本机 HM 激活状态                        |
| **增量模式**            | 新增模块只需添加一个 `.nix` 文件 + 注册到 `default.nix`             |

### 禁止行为

- nmt 测试**不得**直接 `import` 本项目的 NixOS 模块（`nixos/core/…`）
- nmt 测试**不得**在 `tests` 块中进行运行时命令调用
- nmt 测试**不得**依赖真实的 sops 密钥文件
- nmt 测试**不应**与 nixosTest HM-Plane 测试重复同一断言维度

---

## 11. 扩展新 nmt 测试

### 步骤 1：创建测试文件

```nix
# tests/nmt/home/core/exp/sys/base/NEW_TOOL.nix
{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "new_tool: config file present and correct";

  modules = [{
    home = { username = "testuser"; homeDirectory = "/home/testuser"; stateVersion = "25.11"; };
    programs.new_tool = {
      enable   = true;
      settings = { key = "value"; };
    };
  }];

  tests = {
    "new_tool config exists" = {
      path   = ".config/new_tool/config.toml";
      exists = true;
    };
    "new_tool key = value" = {
      path     = ".config/new_tool/config.toml";
      contains = [ "key = \"value\"" ];
    };
  };
}
```

### 步骤 2：注册到 `tests/nmt/default.nix`

```nix
nmt_home_core_exp_sys_base_new_tool = nmtTest ./home/core/exp/sys/base/NEW_TOOL.nix;
```

### 步骤 3：验证

```bash
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_new_tool -L
```

### 步骤 4：同步更新本文档矩阵表格

---

## 12. 常见错误与解决方案

| 错误信息                              | 原因                                           | 解决方案                                        |
| ------------------------------------- | ---------------------------------------------- | ----------------------------------------------- |
| `attribute 'nmt' missing`             | `lib.nmt` 未从 home-manager 注入               | 确认 `hmLib = home-manager.lib` 正确传入        |
| `home.username` not set               | 测试模块缺少 `home.username` / `homeDirectory` | 在 `_lib/base_user.nix` 中定义默认值并 import   |
| `path ".zshrc" does not exist`        | HM zsh 实际写入 `.config/zsh/.zshrc`           | 检查 `programs.zsh.dotDir` 选项                 |
| `contains assertion failed`           | 配置格式变化（空格/引号风格）                  | 用 `matchesPCRE` 代替 `contains` 做模糊匹配     |
| `infinite recursion`                  | 模块导入循环                                   | 测试模块不得导入本项目生产模块                  |
| `error: file 'nixpkgs' was not found` | nmt 测试中使用了 `<nixpkgs>` 路径              | 通过 `{ pkgs, ... }` 参数注入，不使用路径表达式 |

---

## 13. nmt vs nixosTest 决策树

```
需要测试的 home-manager 模块行为是什么？
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  配置文件内容                                                   │
│  - 文件是否存在？                                               │
│  - 文件内容包含某行？                                           │
│  - JSON/TOML 字段值是否正确？                                   │
│  - 文件权限是否正确？                                           │
└──────────────────────────┬──────────────────────────────────────┘
                           │ YES
                           ▼
                    ✅ 使用 nmt
                    tests/nmt/home/...

                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  运行时行为                                                     │
│  - 二进制能否执行？                                             │
│  - 守护进程是否启动？                                           │
│  - 命令输出是否正确？                                           │
│  - 网络端口是否监听？                                           │
└──────────────────────────┬──────────────────────────────────────┘
                           │ YES
                           ▼
                    ✅ 使用 nixosTest (HM-Plane)
                    tests/home/...

                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  NixOS + HM 联合行为                                            │
│  - HM 激活是否与 NixOS 服务正确集成？                           │
│  - 用户登录 shell 是否正确？                                    │
│  - 系统服务与用户服务是否协同？                                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │ YES
                           ▼
                    ✅ 使用 nixosTest (Integration-Plane)
                    tests/integration/...
```

---

_文档由 `tests/nmt/` 目录设计同步维护。新增 nmt 测试时请同步更新 §5 矩阵表格。_
