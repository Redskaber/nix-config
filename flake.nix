# @path: ~/projects/configs/nix-config/flake.nix
# @author: redskaber
# @datetime: 2025-12-12
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# NOTE(roadmap): multi-platform GL app transparent proxy needs a version choice strategy.

{
  description = "Kilig(Redskaber)'s declarative development environment";

  # Binary-cache preference (pull side): try the fleet's own cachix cache
  # first and fall through to the default substituters for anything it
  # does not hold. CI passes the same pair via --option; NixOS hosts get
  # it from platform/nixos/system/core/base/nix.nix. See
  # docs/guides/cache.md for the pull/push story.
  nixConfig = {
    extra-substituters = [ "https://redskaber-nix-config.cachix.org" ];
    extra-trusted-public-keys = [
      "redskaber-nix-config.cachix.org-1:ziIAJzLVe11AexFTrAY3IZVTZQOWUa5vmFB3eeaW8zw="
    ];
  };

  # NOTE(roadmap): flake-dep-manager will take over input bookkeeping.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Second nixpkgs instance — not an overlay: imported in
    # lib/shared/runtime and exposed as shared.upkgs (the overlays/
    # tree only carries additions + patches).
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # NixGl (handler non-nixos gl env depends inject)
    nixgl.url = "github:nix-community/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";

    # NUR (Nix User Repositories)
    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # NMT — Nix Module Test framework (Plane 5). Sourcehut mirror 403s
    # Nix fetchers, hence this GitHub fork; used exclusively by
    # tests/nmt/. Fork delta: the grep assertions pass `--` before the
    # needle so option-looking needles match as text (see
    # tests/nmt/default.nix).
    nmt.url = "github:Redskaber/nmt";
    nmt.flake = false;

    # Sops-Nix
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # ── nix-darwin: darwin system closure ────────────────────────
    # Tarball-pinned (direct archive fetch, exact rev). Branch 26.05
    # must match the nixpkgs release — nix-darwin asserts it at eval
    # time. Home-manager integrates in module mode via darwinModules.
    nix-darwin.url = "https://github.com/LnL7/nix-darwin/archive/c3e90c89649b07d1a96e4b9dd6cd0d6e44b91a74.tar.gz";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Disko — declarative disk partitioning: the interpreter for
    # hosts/<h>/disk.nix layouts. Not in nixpkgs — this input is its
    # registration. Pinned to the newest semver tag (v1.13.0) for
    # reproducibility; tarball-pinned like nix-darwin above. Follows
    # our nixpkgs so layout scripts and the interpreter share one
    # channel. Imported platform-side (platform/nixos/system/core/
    # base/disk.nix) — the entry layer registers, it does not assemble.
    disko.url = "https://github.com/nix-community/disko/archive/56ef5e72fec74b993ad0973b2dfa4eadeb48ba41.tar.gz";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Impermanence — declarative persistent state on ephemeral roots:
    # the interpreter for hosts/<h>/persist.nix declarations. Same
    # story as disko — not in nixpkgs (neither is preservation, its
    # nixpkgs-track successor), registered platform-side in
    # platform/nixos/system/core/base/impermanence.nix. The repo ships
    # no tags, pinned to a stable master rev; tarball-pinned. Follows
    # our nixpkgs; its home-manager input is dev-only — we consume
    # only nixosModules.
    impermanence.url = "https://github.com/nix-community/impermanence/archive/7b1d382faf603b6d264f58627330f9faa5cba149.tar.gz";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";

    # NixOS-WSL — the WSL2 interpreter for the nixos-wsl platform row:
    # a NixOS system layer hosted inside a Windows-managed distro.
    # Registered platform-side (platform/nixos-wsl/system/default.nix);
    # hosts/nixos-wsl/ carries the host data. Tarball-pinned to the
    # nixpkgs-coupled release-26.05 branch. The module owns the WSL
    # surface; platform/nixos/system/core/base/wsl.nix keeps only the
    # true deltas.
    nixos-wsl.url = "https://github.com/nix-community/NixOS-WSL/archive/b98199a76ab180be55f7a6a97bd4984a87c99964.tar.gz";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    # nix-types — the machine contract (docs/architecture/nix-types.md).
    # Upstream ships no tags, so a 40-hex SHA pin is the only pinnable
    # form. The pin answers WHERE; tests/lib/shared/lang/version.nix
    # answers WHAT (lib.version == "3.6.0") — either side drifting
    # alone turns the lang battery red.
    nix-types.url = "github:Redskaber/nix-types/a1a2a1392f64a1943bb741b0184be95a21767a21";

    # Nix dev Shell manager
    pdshell.url = "github:Redskaber/pdshell";
    pdshell.inputs.nixpkgs.follows = "nixpkgs";
    # pdshell builds its ContextPhase FSM on nix-types' enum — pin it to
    # OUR nix-types input so the dispatch tables and the FSM evaluate
    # against ONE rev (SSOT). Without this the lock graph keeps a second
    # nix-types_2 node that can silently drift on partial updates.
    pdshell.inputs.nix-types.follows = "nix-types";

    # Colmena — NixOS deployment: the evaluator behind the colmenaHive
    # output. Tarball-pinned; v0.5.0 is the first release speaking the
    # colmenaHive output protocol (the legacy `colmena` output is
    # deprecated and its evaluator does not work purely on Nix 2.21+).
    # The just recipes pin github:zhaofengli/colmena/v0.5.0 for the same
    # reason (nixpkgs' packaged colmena is channel-lagged).
    #
    # Input wiring: nixpkgs/stable follow ours — makeHive never forces
    # them, and sharing keeps one channel instance. flake-utils IS
    # forced at outputs construction, so it follows pdshell's pin — one
    # flake-utils instance across the flake. nix-github-actions/
    # flake-compat are never forced by .lib.makeHive — empty follows
    # keep the lock graph minimal; a future bump that starts forcing
    # them fails loudly instead of silently fetching something unpinned.
    colmena.url = "https://github.com/zhaofengli/colmena/archive/948491ae031dc0e2e61f0982943dd9964a724bdb.tar.gz";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
    colmena.inputs.stable.follows = "nixpkgs";
    colmena.inputs.flake-utils.follows = "pdshell/flake-utils";
    colmena.inputs.nix-github-actions.follows = "";
    colmena.inputs.flake-compat.follows = "";

    # hyprland config
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    # configuration-orchestrator
    configuration-orchestrator.url = "github:Redskaber/ConfigurationOrchestrator";

    # Wechat
    wechat.url = "github:Redskaber/wechat/auto-update/20261006-225659";
    wechat.inputs.nixpkgs.follows = "nixpkgs";

    # Unpryc
    unrpyc.url = "github:Redskaber/unrpyc";
    unrpyc.inputs.nixpkgs.follows = "nixpkgs";

    # CNMPlayer (china area use)
    cnmplayer.url = "github:Redskaber/cnmplayer";
    cnmplayer.inputs.nixpkgs.follows = "nixpkgs";

    # Trae
    trae.url = "github:Redskaber/trae";
    trae.inputs.nixpkgs.follows = "nixpkgs";

    # Z-library
    z-library.url = "github:Redskaber/z-library";
    z-library.inputs.nixpkgs.follows = "nixpkgs";

    # Zcode
    zcode.url = "github:Redskaber/zcode";
    zcode.inputs.nixpkgs.follows = "nixpkgs";

    # Commit Checker (husky, commitlint, commitizen)
    commit-config.url = "github:Redskaber/commit-config";
    commit-config.flake = false;

    # Pre-commit hooks for nix fmt + statix + deadnix
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";

    # Fcitx5 config
    fcitx5-config.url = "github:Redskaber/fcitx5-config";
    fcitx5-config.flake = false;

    # Qutebrowser config
    qutebrowser-config.url = "github:Redskaber/qutebrowser-config";
    qutebrowser-config.flake = false;

    # Neovim Config
    nvim-config.url = "github:Redskaber/nvim-config";
    nvim-config.flake = false;

    # Emacs config
    emacs-config.url = "github:Redskaber/emacs-config";
    emacs-config.flake = false;

    # Vscode-config
    vscode-config.url = "github:Redskaber/vscode-config";
    vscode-config.flake = false;

    # Starship Config
    starship-config.url = "github:Redskaber/starship-config";
    starship-config.flake = false;

    # Fastfetch Config
    fastfetch-config.url = "github:Redskaber/fastfetch-config";
    fastfetch-config.flake = false;

    # Wezterm Config
    wezterm-config.url = "github:Redskaber/wezterm-config";
    wezterm-config.flake = false;

    # Kitty Config
    kitty-config.url = "github:Redskaber/kitty-config";
    kitty-config.flake = false;

    # Tmux-Config
    tmux-config.url = "github:Redskaber/tmux-config";
    tmux-config.flake = false;

    # Mpv-config
    mpv-config.url = "github:Redskaber/mpv-config";
    mpv-config.flake = false;

    # Btop-config
    btop-config.url = "github:Redskaber/btop-config";
    btop-config.flake = false;

    # Cava-config
    cava-config.url = "github:Redskaber/cava-config";
    cava-config.flake = false;

    # Niri config
    niri-config.url = "github:Redskaber/niri-config";
    niri-config.flake = false;

    # Hypr-config
    hypr-config.url = "github:Redskaber/hypr-config";
    hypr-config.flake = false;

    # Rofi-config
    rofi-config.url = "github:Redskaber/rofi-config";
    rofi-config.flake = false;

    # Swaync-config
    swaync-config.url = "github:Redskaber/swaync-config";
    swaync-config.flake = false;

    # Wallust-config
    wallust-config.url = "github:Redskaber/wallust-config";
    wallust-config.flake = false;

    # Waybar-config
    waybar-config.url = "github:Redskaber/waybar-config";
    waybar-config.flake = false;

    # Wlogout-config
    wlogout-config.url = "github:Redskaber/wlogout-config";
    wlogout-config.flake = false;

    # QuickShell-config
    quickshell-config.url = "github:Redskaber/quickshell-config";
    quickshell-config.flake = false;

    # input-overlay preview
    input-overlay-config.url = "github:Redskaber/input-overlay-config";
    input-overlay-config.flake = false;
  };

  # ── outputs — the entry layer delegates, the linker assembles ──
  # The linker pass (lib/shared/faces.nix) assembles the producer-side
  # artifacts onto the flake-protocol output names; this file carries
  # input registration and one line of delegation. The layer map and
  # the contract live in faces.nix's header.
  outputs = { self, ... }@inputs: import ./lib/shared/faces.nix { inherit self inputs; };
}
