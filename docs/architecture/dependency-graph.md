# 依赖图

> 本文是 README「依赖图」节（T13.1 分层重构时从 README 原样迁出）。
> 依赖速览（inputs 计数锚点）保留在 README。

```
flake.nix（46 inputs）
├── nixpkgs (nixos-26.05)
│   └── nixpkgs-unstable         # 双通道（shared.upkgs，第二实例非 overlay）
├── home-manager (release-26.05)
├── nix-darwin (26.05)           # darwin 系统闭包（tarball-pinned 规避 api 限流）
├── sops-nix                     # secret 管理（版本锁定）
├── disko (v1.13.0)              # 声明式磁盘分区（tarball-pinned；解释器注册于
│                                #   platform/nixos/core/base/disk.nix）
├── impermanence (7b1d382f)      # 声明式持久状态 / ephemeral root（tarball-pinned 至
│                                #   master HEAD；解释器注册于
│                                #   platform/nixos/core/base/impermanence.nix，T5.14）
├── nixos-wsl (release-26.05)    # 第五系统形态的 WSL 解释器（tarball-pinned 至
│                                #   release-26.05 分支；薄门注册于
│                                #   platform/nixos-wsl/default.nix，T7.1）
├── nix-types                    # enum 类型系统（自建）
├── pdshell                      # devShell 管道引擎（自建；follows nix-types 单源）
├── configuration-orchestrator   # wallust 主题注入引擎（自建）
├── nixgl                        # 非 NixOS GL 修复
├── nur                          # 社区包
├── hyprland                     # Wayland WM（最新版）
│   └── hyprland-plugins
├── pre-commit-hooks (git-hooks.nix)  # pre-commit-check derivation
├── wechat                       # 微信（自建 flake）
├── unrpyc                       # RenPy 反编译（自建 flake）
├── cnmplayer                    # 网易云音乐 TUI（自建 flake）
├── trae / z-library / zcode     # 自建 flake
├── nmt                          # HM dotfile 测试框架（flake=false, GitHub mirror）
├── commit-config                # 提交规范（commitlint + commitizen + husky 规则）
└── *-config (flake=false) ×22   # 各工具配置仓库（外部 Git 源）
    nvim · emacs · vscode · starship · fastfetch · wezterm
    kitty · tmux · mpv · btop · cava · niri · hypr · rofi
    swaync · wallust · waybar · wlogout · quickshell · qutebrowser
    input-overlay · fcitx5
```

---
