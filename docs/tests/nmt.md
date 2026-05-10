# nmt — NixOS Module Tests (Home-Manager Plane)

> `docs/tests/nmt.md`
> Updated: 2026-05-10

---

## 目录

1. [nmt 简介](#1-nmt-简介)
2. [nmt vs nixosTest — 技术选型对照](#2-nmt-vs-nixostest--技术选型对照)
3. [nmt 核心概念与结构](#3-nmt-核心概念与结构)
   - 3.1 测试模块组成
   - 3.2 `modules` 块：注入 HM 配置
   - 3.3 `tests` 块：断言文件系统状态
   - 3.4 完整 API 速查表
4. [在 nix-config 中的位置与使用方式](#4-在-nix-config-中的位置与使用方式)
   - 4.1 flake.nix 集成
   - 4.2 nmt runner 封装 (tests/nmt/default.nix)
   - 4.3 与 nixosTest HM-Plane 的互补关系
5. [nmt 测试矩阵（HM-Plane 纯模块断言）](#5-nmt-测试矩阵hm-plane-纯模块断言)
6. [目录结构](#6-目录结构)
7. [编写 nmt 测试：完整示例](#7-编写-nmt-测试完整示例)
8. [运行指南](#8-运行指南)
9. [调试技巧](#9-调试技巧)
10. [设计原则与约束](#10-设计原则与约束)
11. [扩展新 nmt 测试](#11-扩展新-nmt-测试)
12. [常见错误与解决方案](#12-常见错误与解决方案)
13. [nmt vs nixosTest 决策树](#13-nmt-vs-nixostest-决策树)

---

## 1. nmt 简介

**nmt（NixOS Module Tests）** 是专为 [home-manager](https://github.com/nix-community/home-manager) 模块设计的轻量级测试框架。核心思路：

> 不启动虚拟机，直接对 home-manager 激活后产生的**文件系统快照**进行断言。

```
HM 模块配置
    │
    ▼  home-manager build (nix eval)
文件系统树（/home/<user>/ 的声明式快照）
    │
    ▼  nmt 断言引擎
断言：文件存在 / 内容匹配 / JSON 字段 / systemd unit / 权限
```

### 关键特性

| 特性           | 描述                                         |
| -------------- | -------------------------------------------- |
| **零 VM 开销** | 纯 Nix eval，不启动 QEMU，秒级完成           |
| **确定性**     | 断言声明式配置输出，不依赖运行时状态         |
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
| **CI 成本**          | 极低（无 KVM 依赖）                  | 高（需要 KVM / QEMU）                |
| **调试体验**         | `nix-instantiate --eval` 即可        | `nixos-test-driver` 交互式           |
| **check 前缀**       | `nmt_`                               | `home_` / `nixos_`                   |

### 选择原则

```
HM 模块测试问题
        │
        ├─ 问：只需验证文件存在/内容正确？
        │       → 选 nmt  (nmt_*)
        │
        ├─ 问：需要验证守护进程启动 / socket / 运行时行为？
        │       → 选 nixosTest HM-Plane  (home_*)
        │
        └─ 问：需要 NixOS + HM 联合激活验证？
                → 选 nixosTest Integration-Plane  (integration_*)
```

---

## 3. nmt 核心概念与结构

### 3.1 测试模块组成

nmt 测试是一个 Nix 函数，使用 `lib.nmt.buildHomeManagerTest`：

```nix
# tests/nmt/home/core/base/git.nix
{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "git: config files written correctly";

  modules = [
    {
      home = {
        username      = "testuser";
        homeDirectory = "/home/testuser";
        stateVersion  = "25.11";
      };
      programs.git = {
        enable    = true;
        userName  = "Test User";
        userEmail = "test@example.com";
        extraConfig.init.defaultBranch = "main";
      };
    }
  ];

  tests = {
    "git: .config/git/config exists" = {
      path   = ".config/git/config";
      exists = true;
    };
    "git: user.name written" = {
      path     = ".config/git/config";
      contains = [ "[user]" "name = Test User" ];
    };
    "git: defaultBranch = main" = {
      path     = ".config/git/config";
      contains = [ "defaultBranch = main" ];
    };
  };
}
```

### 3.2 `modules` 块：注入 HM 配置

`modules` 是一个 NixOS 模块列表，直接使用 HM 选项语法：

```nix
modules = [
  # 内联配置（最常用）
  {
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";   # 必须匹配项目 stateVersion
    };
    programs.zsh.enable = true;
  }

  # 指向本项目的 HM 模块（路径注入）
  ../../home/core/exp/sys/shell/zsh.nix
];
```

**重要约束：**

- `home.username` / `home.homeDirectory` / `home.stateVersion` 三者必须显式设置
- `stateVersion` 使用项目当前值 `"25.11"`
- 路径相对于测试文件自身，或使用 `inputs.self + "/..."` 绝对路径

### 3.3 `tests` 块：断言文件系统状态

所有路径均相对于 `$HOME`（`/home/testuser/`）：

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

  # 纯文本包含（列表中所有字符串都必须出现）
  "content match" = {
    path     = ".zshrc";
    contains = [ "autoload -U compinit" "HISTSIZE" ];
  };

  # 内容不包含
  "security: no plain password" = {
    path        = ".config/git/config";
    notContains = [ "password" "secret" ];
  };

  # 路径是符号链接
  "is symlink" = {
    path      = ".config/nvim/init.lua";
    isSymlink = true;
  };

  # 路径是目录
  "config dir exists" = {
    path        = ".config/atuin";
    isDirectory = true;
  };

  # 文件权限
  "ssh key mode 0600" = {
    path    = ".ssh/id_ed25519";
    hasMode = "0600";
  };

  # Perl 兼容正则
  "version pattern match" = {
    path         = ".config/starship.toml";
    matchesPCRE  = "success_symbol\\s*=";
  };
};
```

### 3.4 完整 API 速查表

| 断言字段      | 类型       | 描述                                       |
| ------------- | ---------- | ------------------------------------------ |
| `path`        | `string`   | 相对 `$HOME` 的路径（必填）                |
| `exists`      | `bool`     | 文件/目录存在性                            |
| `contains`    | `[string]` | 所有字符串必须出现在文件内容中（AND 语义） |
| `notContains` | `[string]` | 所有字符串不得出现在文件内容中             |
| `isSymlink`   | `bool`     | 是否为符号链接                             |
| `isDirectory` | `bool`     | 是否为目录                                 |
| `hasMode`     | `string`   | 文件权限（如 `"0644"`）                    |
| `matchesPCRE` | `string`   | Perl 兼容正则表达式                        |

---

## 4. 在 nix-config 中的位置与使用方式

### 4.1 flake.nix 集成

```nix
# flake.nix (checks 输出段)
checks.${system} =
  # … 已有的 nixosTest checks (Plane 0-4) …
  //
  # nmt checks: Plane 5 — HM 纯模块断言 (零 VM)
  (import ./tests/nmt/default.nix {
    inherit inputs;
    pkgs  = nixpkgs.legacyPackages.${system};
    hmLib = home-manager.lib;
  });
```

### 4.2 nmt runner 封装

```nix
# tests/nmt/default.nix
{ inputs, pkgs, hmLib, ... }:

let
  nmtTest = path:
    hmLib.hm.internal.buildHomeManagerTest {
      inherit pkgs;
      modules  = [ path ];
      _module.args = { inherit inputs; };
    };
in
{
  # 前缀 nmt_ 区分 nixosTest checks
  nmt_home_core_base_git          = nmtTest ./home/core/base/git.nix;
  nmt_home_core_base_starship     = nmtTest ./home/core/base/starship.nix;
  nmt_home_core_base_direnv       = nmtTest ./home/core/base/direnv.nix;
  nmt_home_core_base_atuin        = nmtTest ./home/core/base/atuin.nix;
  nmt_home_core_base_zoxide       = nmtTest ./home/core/base/zoxide.nix;
  nmt_home_core_base_tmux         = nmtTest ./home/core/base/tmux.nix;
  nmt_home_core_base_bat          = nmtTest ./home/core/base/bat.nix;
  # shell
  nmt_home_core_exp_sys_shell_zsh  = nmtTest ./home/core/exp/sys/shell/zsh.nix;
  nmt_home_core_exp_sys_shell_fish = nmtTest ./home/core/exp/sys/shell/fish.nix;
  # srv
  nmt_home_core_srv_gnupg         = nmtTest ./home/core/srv/gnupg.nix;
  nmt_home_core_srv_mako          = nmtTest ./home/core/srv/mako.nix;
  # app
  nmt_home_core_exp_app_nvim      = nmtTest ./home/core/exp/app/nvim.nix;
  # env/dev
  nmt_home_env_dev_git_config     = nmtTest ./home/env/dev/git.nix;
}
```

### 4.3 与 nixosTest HM-Plane 的互补关系

```
home/core/exp/sys/base/git.nix
        │
        ├─ nmt_home_core_base_git          ← 断言 .config/git/config 内容
        │    (tests/nmt/home/core/base/git.nix)
        │    纯 eval，零 VM，< 10 s
        │    验证: [user], name, email, defaultBranch, delta, notContains password
        │
        └─ home_core_exp_sys_base_git      ← 断言 git 二进制可执行、commit 流程
             (tests/home/core/exp/sys/base/git.nix)
             QEMU VM，运行时验证，~2 min
             验证: git --version, git init/commit/log, credential behavior

两者不重复覆盖:
  nmt  → "配置文件内容是否正确写入"
  nixosTest → "工具是否可运行且行为符合预期"
```

---

## 5. nmt 测试矩阵（HM-Plane 纯模块断言）

所有 nmt 测试前缀为 `nmt_`，路径在 `tests/nmt/` 下（镜像 `home/` 结构）。

### 5.1 core/base — dotfile 内容断言

| check 名称                    | 测试文件                          | 验证点                                                 |
| ----------------------------- | --------------------------------- | ------------------------------------------------------ |
| `nmt_home_core_base_git`      | `nmt/home/core/base/git.nix`      | .config/git/config: [user], name, email, branch, delta |
| `nmt_home_core_base_starship` | `nmt/home/core/base/starship.nix` | .config/starship.toml: [character], success_symbol     |
| `nmt_home_core_base_direnv`   | `nmt/home/core/base/direnv.nix`   | .config/direnv/direnvrc: nix-direnv sourced            |
| `nmt_home_core_base_atuin`    | `nmt/home/core/base/atuin.nix`    | .config/atuin/config.toml: style, sync; systemd unit   |
| `nmt_home_core_base_zoxide`   | `nmt/home/core/base/zoxide.nix`   | .zshrc: zoxide init hook present                       |
| `nmt_home_core_base_tmux`     | `nmt/home/core/base/tmux.nix`     | .config/tmux/tmux.conf: prefix C-a, vi mode, mouse     |
| `nmt_home_core_base_bat`      | `nmt/home/core/base/bat.nix`      | .config/bat/config: theme TwoDark, --style             |

### 5.2 core/exp/sys/shell — shell 配置断言

| check 名称                         | 测试文件                               | 验证点                                              |
| ---------------------------------- | -------------------------------------- | --------------------------------------------------- |
| `nmt_home_core_exp_sys_shell_zsh`  | `nmt/home/core/exp/sys/shell/zsh.nix`  | .zshrc: compinit, HISTSIZE=50000, alias, no .bashrc |
| `nmt_home_core_exp_sys_shell_fish` | `nmt/home/core/exp/sys/shell/fish.nix` | .config/fish/config.fish: abbr, aliases             |

### 5.3 core/srv — 服务配置断言

| check 名称                | 测试文件                      | 验证点                                                       |
| ------------------------- | ----------------------------- | ------------------------------------------------------------ |
| `nmt_home_core_srv_gnupg` | `nmt/home/core/srv/gnupg.nix` | .gnupg/gpg-agent.conf: enable-ssh-support, default-cache-ttl |
| `nmt_home_core_srv_mako`  | `nmt/home/core/srv/mako.nix`  | .config/mako/config: default-timeout, border-size            |

### 5.4 core/exp/app — 应用断言

| check 名称                   | 测试文件                         | 验证点                         |
| ---------------------------- | -------------------------------- | ------------------------------ |
| `nmt_home_core_exp_app_nvim` | `nmt/home/core/exp/app/nvim.nix` | .nix-profile exists (激活成功) |

### 5.5 env/dev — 开发环境配置断言

| check 名称                    | 测试文件                   | 验证点                                       |
| ----------------------------- | -------------------------- | -------------------------------------------- |
| `nmt_home_env_dev_git_config` | `nmt/home/env/dev/git.nix` | delta pager, core.editor=nvim, defaultBranch |

---

## 6. 目录结构

```
tests/nmt/
├── default.nix                          ← nmt 注册表 (data-driven, nmtTest runner)
└── home/
    ├── core/
    │   ├── base/
    │   │   ├── git.nix                  ← git config 断言
    │   │   ├── starship.nix             ← starship.toml 断言
    │   │   ├── direnv.nix               ← direnvrc 断言
    │   │   ├── atuin.nix                ← config.toml + systemd unit 断言
    │   │   ├── zoxide.nix               ← zsh hook 断言
    │   │   ├── tmux.nix                 ← tmux.conf 断言
    │   │   └── bat.nix                  ← bat config 断言
    │   ├── srv/
    │   │   ├── gnupg.nix                ← gpg-agent.conf 断言
    │   │   └── mako.nix                 ← mako config 断言
    │   └── exp/
    │       ├── app/
    │       │   └── nvim.nix             ← neovim 激活断言
    │       └── sys/shell/
    │           ├── zsh.nix              ← .zshrc 断言
    │           └── fish.nix             ← config.fish 断言
    └── env/dev/
        └── git.nix                      ← 开发 git config 断言
```

---

## 7. 编写 nmt 测试：完整示例

### 7.1 基础文件断言

```nix
{ lib, ... }:
lib.nmt.buildHomeManagerTest {
  description = "direnv: nix-direnv integration written";

  modules = [{
    home = {
      username = "testuser"; homeDirectory = "/home/testuser";
      stateVersion = "25.11";
    };
    programs.direnv = {
      enable            = true;
      nix-direnv.enable = true;
    };
  }];

  tests = {
    "direnv: config dir exists" = {
      path        = ".config/direnv";
      isDirectory = true;
    };
    "direnv: nix-direnv in direnvrc" = {
      path     = ".config/direnv/direnvrc";
      contains = [ "nix-direnv" ];
    };
  };
}
```

### 7.2 TOML 内容断言

```nix
tests = {
  "starship: [character] section" = {
    path     = ".config/starship.toml";
    contains = [ "[character]" "success_symbol" ];
  };
  "starship: add_newline = false" = {
    path     = ".config/starship.toml";
    contains = [ "add_newline = false" ];
  };
};
```

### 7.3 systemd unit 断言

```nix
tests = {
  "atuin: systemd service written" = {
    path   = ".config/systemd/user/atuin.service";
    exists = true;
  };
  "gpg-agent: socket unit exists" = {
    path   = ".config/systemd/user/gpg-agent.socket";
    exists = true;
  };
};
```

### 7.4 负向断言

```nix
tests = {
  "no .bash_profile generated (using zsh)" = {
    path   = ".bash_profile";
    exists = false;
  };
  "no plain-text credentials in gitconfig" = {
    path        = ".config/git/config";
    notContains = [ "password" "secret" "token" ];
  };
};
```

### 7.5 正则表达式断言

```nix
tests = {
  "starship: success_symbol PCRE" = {
    path        = ".config/starship.toml";
    matchesPCRE = "success_symbol\\s*=\\s*\"";
  };
};
```

---

## 8. 运行指南

### 全部 nmt checks

```bash
# nmt checks 前缀 nmt_，与 nixosTest checks 区分
nix flake check
```

### 仅运行 nmt 平面（推荐用于快速反馈）

```bash
# 列出所有 nmt_* check 名称
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)'

# 批量构建（无需 KVM）
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  | tr -d '[]"' | tr ' ' '\n' | grep . \
  | xargs -P4 -I{} nix build ".#checks.x86_64-linux.{}" -L --no-link
```

### 单个 nmt check

```bash
nix build .#checks.x86_64-linux.nmt_home_core_base_git -L
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_shell_zsh -L
```

### justfile 集成

```bash
# 运行所有 nmt 测试
just test-nmt

# 运行单个 nmt 测试
just test-nmt-one nmt_home_core_base_git
```

---

## 9. 调试技巧

### 查看断言输出

```bash
nix build .#checks.x86_64-linux.nmt_home_core_base_git -L 2>&1 | tail -20
```

### nix repl 检查

```bash
nix repl
:lf .
# 检查 check 属性存在
outputs.checks.x86_64-linux ? nmt_home_core_base_git
# 查看测试定义
outputs.checks.x86_64-linux.nmt_home_core_base_git
```

### 手动构建 HM 激活包 (eval 阶段产物)

```bash
# 验证 modules 配置本身可 eval
nix-instantiate --eval -E '
  let
    pkgs   = import <nixpkgs> {};
    hm     = builtins.getFlake "github:nix-community/home-manager";
    result = hm.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [{
        home.username      = "testuser";
        home.homeDirectory = "/home/testuser";
        home.stateVersion  = "25.11";
        programs.git.enable = true;
        programs.git.userName = "T";
        programs.git.userEmail = "t@t.t";
      }];
    };
  in result.activationPackage
'
```

### 查看生成的配置文件路径

```bash
# 构建后查看输出目录结构
nix build .#checks.x86_64-linux.nmt_home_core_base_git --no-link --print-out-paths
ls $(nix build .#checks.x86_64-linux.nmt_home_core_base_git --no-link --print-out-paths)/
```

---

## 10. 设计原则与约束

| 原则                | 实施                                                 |
| ------------------- | ---------------------------------------------------- |
| 零 VM               | `buildHomeManagerTest`，不含 `nodes` 属性            |
| 不测试运行时行为    | 只断言文件存在/内容；进程行为交给 nixosTest HM-Plane |
| 不依赖 SOPS secrets | 测试配置中不引用 sopsFile 路径                       |
| 每模块一测试文件    | 1:1 镜像 `home/` 源模块结构                          |
| 负向安全断言        | 每个 dotfile 测试加 `notContains` 防止密码泄漏       |
| stateVersion 统一   | 所有 nmt 测试使用 `"25.11"` 与项目一致               |

---

## 11. 扩展新 nmt 测试

```
新 HM 模块 home/core/exp/sys/base/new-tool.nix
        │
        ├─ 创建 tests/nmt/home/core/base/new-tool.nix
        │    lib.nmt.buildHomeManagerTest { modules=[...]; tests={...}; }
        │
        ├─ 注册到 tests/nmt/default.nix
        │    nmt_home_core_base_new_tool = nmtTest ./home/core/base/new-tool.nix;
        │
        └─ tests/default.nix 无需修改
             (nmtChecks 透传 tests/nmt/default.nix 全部条目)
```

**最小模板：**

```nix
# tests/nmt/home/core/base/new-tool.nix
{ lib, ... }:
lib.nmt.buildHomeManagerTest {
  description = "new-tool: config written correctly";
  modules = [{
    home = {
      username = "testuser"; homeDirectory = "/home/testuser";
      stateVersion = "25.11";
    };
    programs.new-tool = {
      enable   = true;
      settings.theme = "dark";
    };
  }];
  tests = {
    "new-tool: config exists" = {
      path   = ".config/new-tool/config";
      exists = true;
    };
    "new-tool: theme written" = {
      path     = ".config/new-tool/config";
      contains = [ "theme" "dark" ];
    };
    "new-tool: no secrets leaked" = {
      path        = ".config/new-tool/config";
      notContains = [ "password" "secret" "token" ];
    };
  };
}
```

---

## 12. 常见错误与解决方案

| 错误                                       | 原因                            | 解决方案                                            |
| ------------------------------------------ | ------------------------------- | --------------------------------------------------- |
| `home.username not set`                    | modules 缺少必需字段            | 补充 `home.username / homeDirectory / stateVersion` |
| `attribute 'buildHomeManagerTest' missing` | hmLib 传参错误                  | 确认 `hmLib = inputs.home-manager.lib`              |
| `path '..' is not valid`                   | nmt 中引用了 sopsFile           | 移除 sopsFile，或使用 mock 值                       |
| `test "x" failed: file does not exist`     | HM 选项未启用或路径判断有误     | 检查 `programs.X.enable = true`，确认实际路径       |
| `contains [] failed`                       | 配置文件内容与期望字符串不匹配  | `nix-instantiate` 验证实际生成内容                  |
| `infinite recursion`                       | modules 中引用了项目全局 shared | nmt 测试不导入 shared；用内联值替代                 |

---

## 13. nmt vs nixosTest 决策树

```
需要测试 Home-Manager 模块
            │
            ▼
  ┌─ 只需验证 dotfile 内容正确？
  │    (文件存在/内容匹配/JSON字段/systemd unit)
  │
  │  YES → nmt (tests/nmt/*)   ← 零 VM, < 10 s, 无 KVM 要求
  │         check 前缀: nmt_
  │
  NO
  │
  ▼
  ┌─ 需要验证运行时行为？
  │    (二进制可执行, 服务启动, 进程, 端口, 命令输出)
  │
  │  YES → nixosTest HM-Plane (tests/home/*)
  │         check 前缀: home_
  │         QEMU VM, ~2–8 min, 需要 KVM
  │
  NO (两者都需要)
  │
  ▼
  两者都写：
    nmt_*  → 配置文件内容
    home_* → 运行时行为
  (推荐对核心工具同时覆盖)
```
