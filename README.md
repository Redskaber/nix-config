# 🧊 nix-config

My Nix flake for managing NixOS and Home Manager setups across machines.

Goals:
- Keep the system layer minimal (only boot, drivers, security).
- Manage user environment declaratively with Home Manager.
- Provide on-demand, isolated development shells—no global tool installs.

---

## 🗂️ Structure

```
├── flake.nix                 # Flake entrypoint
├── nixos/                    # Minimal NixOS config
│   └── core/                 # Boot, network, GPU, etc.
│   └── wm/hyprland/          # Hyprland + basic Wayland tools
├── home/                     # Home Manager modules
│   ├── core/sys/             # Shell, git, fonts, CLI utils
│   ├── core/app/             # GUI apps (nvim, wezterm, obsidian…)
│   ├── core/dev/             # Language-specific dev environments
│   └── hosts/                # Host profiles (nixos, generic linux)
├── lib/dev/                  # Utilities for building dev shells
│   ├── mkShell.nix           # Helper to combine language modules
│   └── shells.nix            # Auto-generates shells from ./dev/*.nix
└── export/                   # Reusable NixOS/Home modules
```

---

## ⚙️ How It Works

### System & User Config
- NixOS config is kept small—only what’s needed to run the machine.
- Most user-facing tools and dotfiles are managed by Home Manager.
- App configurations (Neovim, Starship, Wezterm, etc.) live in separate repos and are linked via `xdg.configFile`.  
  Example:
  ```nix
  xdg.configFile."nvim".source = inputs.nvim-config;
  ```

### Development Shells
Instead of listing all packages in one `mkShell`, each language defines its own module under `home/core/dev/`:

- `c.nix` → C toolchain + env vars
- `python.nix` → Python + common dev tools
- `rust.nix` → Rustup-free rust toolchain

Composite environments are defined in `home/core/dev/default.nix`:
```nix
cpython = {
  combinFrom = [ dev.c dev.python ];
};
```

The helper in `lib/dev/mkShell.nix` merges inputs and hooks, avoiding duplication.

You can enter any shell with:
```bash
nix develop .#python-machine
nix develop .#cpython
nix develop .#rust
```

All shells are ephemeral—nothing affects your global environment.

---

## ▶️ Usage

### On NixOS
```bash
sudo nixos-rebuild switch --flake .#kilig-nixos
home-manager switch --flake .#kilig@nixos
```

### On other Linux systems
```bash
home-manager switch --flake .#kilig@extensa
```

> Note: `hardware-configuration.nix` is not tracked—generate per machine.

---

## 📦 Inputs

Most personal config repos (e.g. `nvim-config`, `starship-config`) are added as non-flake inputs:
```nix
nvim-config.url = "github:Redskaber/nvim-config";
nvim-config.flake = false;
```
This lets them remain simple file trees, usable even outside Nix.

---

> — [@Redskaber](https://github.com/Redskaber)







