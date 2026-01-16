# 🧊 nix-config

> **Minimal system. Maximal user freedom. Precise development environments.**

My declarative Nix flake for **NixOS** and **Home Manager**, built on three core principles:

1. **System layer**: Bare minimum — only what’s essential for boot, security, and hardware.
2. **User layer**: Rich, modular, and fully declarative — your desktop, tools, and dotfiles.
3. **Dev layer**: On-demand, composable development shells — no bloat, just what you need.

---

## 🗂️ Structure Overview

```
├── flake.nix                 # Flake entrypoint
├── nixos/                    # NixOS system configuration (minimal)
│   └── core/                 # Boot, network, sound, drivers, etc.
│   └── wm/hyprland/          # Hyprland compositor integration
├── home/                     # Home Manager (user environment)
│   ├── core/sys/             # Shell, git, fonts, CLI utils
│   ├── core/app/             # GUI apps: nvim, wezterm, steam, etc.
│   ├── core/dev/             # Language modules & dev shell definitions
│   └── hosts/                # Host-specific HM profiles (linux, nixos)
├── lib/dev/                  # Custom dev shell engine (`mk-dev-shell`)
└── export/                   # Reusable modules (for external flakes)
```

---

## ⚡ Quick Start

### On NixOS
```bash
# Rebuild system (fast — only core services)
sudo nixos-rebuild switch --flake .#kilig-nixos

# Activate user environment
home-manager switch --flake .#kilig@nixos
```

### On any Linux (via Home Manager standalone)
```bash
home-manager switch --flake .#kilig@extensa
```

> 💡 System stays clean. All GUI apps, shells, and configs live in your user profile.

---

## 🛠️ Development Shells

Powered by a custom **composable dev shell engine**. Each language is a reusable module; environments are declared via composition.

### Available shells
```bash
nix flake show  # See all devShells
```

### Examples
```bash
# Full-stack dev environment (C/C++/Rust/Python/JS/etc.)
nix develop

# CPython extension development (C + Python only)
nix develop .#cpython

# Rust-only toolchain
nix develop .#rust

# Web dev (JS/TS/Node)
nix develop .#web
```

Each shell:
- Loads **only necessary packages**
- Sets up **language-specific hooks & env vars**
- Avoids duplication via **smart merging & deduplication**

Define new combinations in [`home/core/dev/default.nix`](./home/core/dev/default.nix).

---

## 🌐 Window Manager

- **Hyprland** (Wayland compositor)
- Full ecosystem: `waybar`, `swaync`, `rofi`, `swaylock`, `wl-clipboard`, etc.
- All configured declaratively via Home Manager.

---

## 🔒 Philosophy

- **No fat system**: `environment.systemPackages` is intentionally sparse.
- **User-centric**: Your shell, editor, browser, and workflow — all yours.
- **Reproducible**: Every environment is pinned via `flake.lock`.
- **Portable**: Same config works across NixOS and generic Linux.

> “Give me a minimal kernel, and I shall build my world in userspace.”

---

## 📦 Inputs Highlights

- `nixpkgs` (stable `25.11`) + `nixpkgs-unstable` (selective access)
- `home-manager` (release-25.11)
- `nixgl` for GPU-accelerated apps on non-NixOS
- Personal config repos (neovim, starship, wezterm, etc.) as Git submodules

---

## 📝 Notes

- Replace `kilig-nixos`, `kilig@nixos`, etc. with your hostname/username if forking.
- Hardware config (`hardware-configuration.nix`) is **not tracked** — generate per-machine.
- All dev environments are **ephemeral** — nothing installed globally.

---

> Crafted with ☕ and Nix  
> — [@Redskaber](https://github.com/Redskaber)
```

