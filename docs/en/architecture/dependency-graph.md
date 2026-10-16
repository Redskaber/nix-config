# Dependency graph

> English mirror of [docs/architecture/dependency-graph.md](../../architecture/dependency-graph.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> This document is the "Dependency graph" section of the README (migrated verbatim out of the README during the T13.1 layered refactor).
> The dependency quick overview (the inputs count anchor) is kept in the README.

```
flake.nix (47 inputs)
├── nixpkgs (nixos-26.05)
│   └── nixpkgs-unstable         # dual channels (shared.upkgs; the second instance is not an overlay)
├── home-manager (release-26.05)
├── nix-darwin (26.05)           # the darwin system closure (tarball-pinned to dodge the API rate limit)
├── sops-nix                     # secret management (version-locked)
├── disko (v1.13.0)              # declarative disk partitioning (tarball-pinned; the interpreter is registered in
│                                #   platform/nixos/system/core/base/disk.nix)
├── impermanence (7b1d382f)      # declarative persistent state / ephemeral root (tarball-pinned to
│                                #   master HEAD; the interpreter is registered in
│                                #   platform/nixos/system/core/base/impermanence.nix, T5.14)
├── nixos-wsl (release-26.05)    # the WSL interpreter of the fifth system form (tarball-pinned to the
│                                #   release-26.05 branch; the thin gate is registered in
│                                #   platform/nixos-wsl/system/default.nix, T7.1)
├── nix-types                    # the enum type system (in-house)
├── pdshell                      # the devShell pipeline engine (in-house; follows nix-types — single source)
├── configuration-orchestrator   # the wallust theme-injection engine (in-house)
├── nixgl                        # the non-NixOS GL fixup
├── nur                          # community packages
├── hyprland                     # the Wayland WM (latest)
│   └── hyprland-plugins
├── pre-commit-hooks (git-hooks.nix)  # pre-commit-check derivation
├── wechat                       # WeChat (in-house flake)
├── unrpyc                       # a RenPy decompiler (in-house flake)
├── cnmplayer                    # a NetEase Cloud Music TUI (in-house flake)
├── trae / z-library / zcode     # in-house flakes
├── nmt                          # the HM dotfile test framework (flake=false, GitHub mirror)
├── commit-config                # commit conventions (commitlint + commitizen + husky rules)
└── *-config (flake=false) ×22   # per-tool config repos (external Git sources)
    nvim · emacs · vscode · starship · fastfetch · wezterm
    kitty · tmux · mpv · btop · cava · niri · hypr · rofi
    swaync · wallust · waybar · wlogout · quickshell · qutebrowser
    input-overlay · fcitx5
```

---
