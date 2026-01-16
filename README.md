# 🧊 nix-config

> **Minimal system. Maximal user freedom. Precise, composable development environments.**

My declarative Nix flake for **NixOS** and **Home Manager**, built on three pillars:

1. **System layer**: Bare metal — only boot, drivers, security.
2. **User layer**: Fully declarative desktop (Hyprland), apps, and dotfiles via Home Manager.
3. **Dev layer**: On-demand, **composable dev shells** powered by a custom engine — no global pollution.

---

## 🗂️ Project Structure

```
├── flake.nix                 # Flake entrypoint
├── nixos/                    # Minimal NixOS config (core + WM)
│   └── core/                 # Boot, network, sound, GPU drivers
│   └── wm/hyprland/          # Wayland compositor setup
├── home/                     # Home Manager profiles
│   ├── core/sys/             # Shell (zsh/fish), git, fonts, CLI tools
│   ├── core/app/             # GUI apps: nvim, wezterm, steam, obsidian...
│   ├── core/dev/             # **Language modules & composite shells**
│   └── hosts/                # Host-specific HM (nixos, linux)
├── lib/dev/                  # **Custom dev shell engine**
│   ├── mkShell.nix           # Smart combinator with dedup & hook merging
│   └── shells.nix            # Auto-generates devShells from ./dev/*.nix
└── export/                   # Reusable modules for other flakes
```

---

## ⚡ Quick Start

### On NixOS
```bash
sudo nixos-rebuild switch --flake .#kilig-nixos
home-manager switch --flake .#kilig@nixos
```

### On any Linux (standalone Home Manager)
```bash
home-manager switch --flake .#kilig@extensa
```

> 💡 Your system stays clean. All development happens in ephemeral shells.

---

## 🛠️ Composable Development Shells

This is the **core innovation**: development environments are **declared as compositions of language modules**, not hardcoded lists.

### How it works
- Each language lives in `home/core/dev/<lang>.nix` → returns an **attrset of variants** (`default`, `machine`, etc.)
- Composite shells (e.g., `cpython`) are defined in `home/core/dev/default.nix` using `combinFrom = [ dev.c dev.python ]`
- The engine (`lib/dev/mkShell.nix`) **deduplicates packages**, **merges hooks**, and **resolves dependencies**

### Available Shells
Run `nix flake show` to see all:
```bash
# Full-stack environment (C/C++/Rust/Py/JS/etc.)
nix develop

# CPython extension dev (C + Python only)
nix develop .#cpython

# Python for ML/DL (with uv, ruff, pyright + scientific stack)
nix develop .#python-machine

# Language-specific minimal shells
nix develop .#rust
nix develop .#java
nix develop .#web  # (via combinFrom in default.nix)
```

Each shell:
- Loads **only necessary inputs**
- Sets up **language-specific env vars & aliases**
- Executes **pre/post hooks** at every stage (`preInputsHook`, `postShellHook`, etc.)
- Avoids duplication via **smart merging**

> 🔍 See [`home/core/dev/c.nix`](./home/core/dev/c.nix) and [`home/core/dev/python.nix`](./home/core/dev/python.nix) for real-world examples.

---

## 🌐 Window Manager

- **Hyprland** (Wayland) with full ecosystem:
  - `waybar`, `swaync`, `rofi`, `swaylock`, `wl-clipboard`
- All configured **declaratively** via Home Manager
- No imperative scripts — everything is reproducible

---

## 🔒 Philosophy

- **System purity**: `environment.systemPackages` is nearly empty.
- **User sovereignty**: Your editor, shell, and workflow — fully yours.
- **Dev precision**: No “global Python” or “system Rust”. Every project gets exactly what it needs.
- **Portability**: Same config works on NixOS and generic Linux.

> “I don’t install tools. I compose environments.”

---

## 🧠 Under the Hood: The Dev Shell Engine

Your custom `mkDevShell` provides:

| Feature | Description |
|--------|-------------|
| **`combinFrom`** | Declare dependencies as **config attrsets**, not package lists |
| **Deduplication** | `pkgs.lib.unique` on `buildInputs` / `nativeBuildInputs` |
| **Hook Merging** | Concatenates `preInputsHook`, `postShellHook`, etc. from all layers |
| **Variant Support** | `python.nix` → `python` (default) + `python-machine` |
| **Function Hooks** | Optional `preShellHookFn` for dynamic logic |

This turns dev environments into **first-class, composable data** — not just shell scripts.

---

## 📦 Inputs

- `nixpkgs` (stable `25.11`)
- `nixpkgs-unstable` (selective access via overlays)
- `home-manager` (release-25.11)
- Personal config repos as submodules (neovim, starship, etc.)

---

## 📝 Notes

- Hardware config (`hardware-configuration.nix`) is **not tracked** — generate per machine.
- All dev shells are **ephemeral** — nothing leaks into your global environment.
- Use `direnv` + `use flake` for seamless project integration (see `python-machine` example).

---

> Crafted with ☕ and Nix  
> — [@Redskaber](https://github.com/Redskaber)




