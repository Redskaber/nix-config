# @path: ~/projects/configs/nix-config/flake.nix
# @author: redskaber
# @datetime: 2025-12-12
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# NOTE(roadmap): multi-platform GL app transparent proxy needs a version choice strategy.

{
  description = "Kilig(Redskaber)'s declarative development environment";

  # NOTE(roadmap): flake-dep-manager will take over input bookkeeping.
  inputs = {
    # Nixpkgs (url version)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Unstable is NOT an overlay here: it is a second nixpkgs instance
    # imported in lib/shared/runtime and exposed as shared.upkgs (the
    # overlays/ tree only carries additions + patches).

    # NixGl (handler non-nixos gl env depends inject)
    nixgl.url = "github:nix-community/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";

    # NUR (Nix User Repositories)
    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # NMT — Nix Module Test framework (Plane 5 nmt-Plane)
    # Mirror of git@git.sr.ht:~rycee/nmt (sourcehut returns HTTP 403 to Nix
    # fetchers due to bot-protection; github.com/Redskaber/nmt is accessible).
    # Used exclusively by tests/nmt/default.nix.
    # Fork delta at the pinned rev (25fe4c8): the three grep assertions pass
    # `--` before the needle — option-looking needles ("--smart-case") are
    # matched as text; the pin is the guarantee the nmt-Plane's needle
    # assertions rely on (see tests/nmt/default.nix).
    nmt.url = "github:Redskaber/nmt";
    nmt.flake = false;

    # Sops-Nix
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # ── nix-darwin (T3.2): darwin system closure ─────────────────────
    # Tarball-pinned (github: short syntax would need API resolution;
    # the archive URL fetches directly and pins the exact rev).
    # Branch nix-darwin-26.05 — nix-darwin release-checks its branch
    # against the nixpkgs release it is built for (26.05 here); master
    # (26.11) would fail the eval-time assert.
    # Home-manager integrates in module mode via darwinModules.
    nix-darwin.url = "https://github.com/LnL7/nix-darwin/archive/c3e90c89649b07d1a96e4b9dd6cd0d6e44b91a74.tar.gz";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Disko — declarative disk partitioning (T5.13): the interpreter for
    # hosts/<h>/disk.nix layouts. Unlike the facter module (upstreamed
    # into nixpkgs' default module list, T5.12), disko is NOT in nixpkgs
    # (checked against the locked nixos-26.05 tree) — this input IS its
    # registration. Pinned to the newest semver tag (v1.13.0, 2026-01)
    # rather than master: reproducibility over chasing unreleased fixes;
    # the module surface it uses (module system, extendModules, lib
    # types) is stable across the Jan→Apr gap to the locked nixpkgs.
    # Tarball-pinned like nix-darwin above (github: short syntax would
    # need API resolution and this sandbox's api.github.com is
    # rate-limited; the archive URL fetches directly and pins the exact
    # rev of the tag). The module evaluates against OUR nixpkgs
    # (follows) so layout scripts and the interpreter share one channel.
    # The import happens platform-side (see
    # platform/nixos/system/core/base/disk.nix), never here — the entry layer
    # registers producers, it does not assemble consumers.
    disko.url = "https://github.com/nix-community/disko/archive/56ef5e72fec74b993ad0973b2dfa4eadeb48ba41.tar.gz";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Impermanence — declarative persistent state on ephemeral roots
    # (T5.14): the interpreter for hosts/<h>/persist.nix declarations.
    # Same registration story as disko above (capability registered
    # platform-side in platform/nixos/system/core/base/impermanence.nix, data
    # as host facts). NOT in nixpkgs — checked against the locked
    # nixos-26.05 tree, and neither is preservation, its nixpkgs-track
    # successor (nix-community/preservation, nixpkgs#265640); the
    # preservation migration path is recorded in that module's header
    # (when it lands in nixpkgs, the T5.12 zero-input precedent applies).
    # Pinned to master HEAD 7b1d382f (the repo ships no tags — rolling
    # master only): reproducibility over chasing the head; the module
    # surface we consume (environment.persistence submodule) is stable
    # and the project is in slow maintenance mode. Tarball-pinned like
    # disko (same sandbox reason: direct archive fetch, exact rev).
    # nixpkgs IS followed so the module's lib evaluates against the
    # same channel as everything else; impermanence's home-manager
    # input is dev-only (its own checks) and left un-followed — we
    # consume only nixosModules.
    impermanence.url = "https://github.com/nix-community/impermanence/archive/7b1d382faf603b6d264f58627330f9faa5cba149.tar.gz";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";

    # NixOS-WSL — the WSL2 interpreter for the nixos-wsl platform row
    # (T7.1): the fifth system form, a NixOS system layer hosted
    # inside a Windows-managed distro. Registered platform-side in
    # platform/nixos-wsl/system/default.nix (the thin door that reuses the
    # nixos customs); hosts/nixos-wsl/ carries the host's data.
    # Tarball-pinned to the release-26.05 branch (release branches
    # are nixpkgs-coupled since 2505.7.0 — main tracks unstable).
    # The module owns the WSL surface (wsl.conf generation, systemd
    # hosting, interop/binfmt, boot/kernel/loader subtraction); our
    # platform/nixos/system/core/base/wsl.nix keeps only the true deltas.
    nixos-wsl.url = "https://github.com/nix-community/NixOS-WSL/archive/b98199a76ab180be55f7a6a97bd4984a87c99964.tar.gz";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    # Nix types expend from my costum
    # Machine contract (nix-types adjudication, docs/architecture/nix-types.md):
    # pinned to the audited rev — upstream has NO tags (git ls-remote --tags
    # is empty), so a 40-hex SHA is the only pinnable form. Same family as
    # the action-SHA contract (9ebe543): the weekly update stops dragging
    # nix-types HEAD, upgrades become deliberate decisions; the 732-line
    # lang battery plus nix-types' own 446-test checks.testSuite are the
    # dual safety net that catches a bad bump.
    # T25.1: 815fc3f → a1a2a13 (v3.6.0 — the machine-assertable version
    # identity + PATTERNS.md, adopted upstream). The bump is a TWO-file
    # deliberate decision by contract (docs/PATTERNS.md pattern #2 in
    # nix-types): this pin answers WHERE, tests/lib/shared/lang/version.nix
    # answers WHAT (lib.version == "3.6.0") — either side drifting alone
    # turns the battery red in one line.
    nix-types.url = "github:Redskaber/nix-types/a1a2a1392f64a1943bb741b0184be95a21767a21";

    # Nix dev Shell manager
    pdshell.url = "github:Redskaber/pdshell";
    pdshell.inputs.nixpkgs.follows = "nixpkgs";
    # pdshell builds its ContextPhase FSM on nix-types' enum — pin it to
    # OUR nix-types input so the dispatch tables and the FSM evaluate
    # against ONE rev (SSOT). Without this the lock graph keeps a second
    # nix-types_2 node that can silently drift on partial updates.
    pdshell.inputs.nix-types.follows = "nix-types";

    # Colmena — NixOS deployment (T20.1): the evaluator behind the
    # colmenaHive output. Tarball-pinned like disko/nix-darwin above
    # (github: short syntax would need API resolution; the archive URL
    # pins the exact rev). v0.5.0 is the first release speaking the
    # colmenaHive output protocol — the legacy `colmena` output is
    # deprecated and its nix-instantiate evaluator does not work
    # purely on Nix 2.21+. The CLI in the just recipes pins
    # github:zhaofengli/colmena/v0.5.0 for the same reason
    # (nixpkgs' packaged colmena is channel-lagged and would try to
    # read the deprecated output instead).
    #
    # Input wiring (the lock graph mirrors these):
    #  - nixpkgs/stable follow ours — makeHive never asks for them
    #    (only eachSystem's thunk construction runs when .lib is
    #    forced), and sharing keeps one instance of the same channel
    #    (stable IS the release-26.05 branch our nixpkgs pins).
    #  - flake-utils IS forced the moment colmena's outputs attrset is
    #    constructed (eachSystem runs), so it follows pdshell's pin —
    #    ONE flake-utils instance across the flake (the follows-
    #    pins-one-instance discipline, same shape as pdshell →
    #    nix-types above).
    #  - nix-github-actions/flake-compat are never forced by
    #    .lib.makeHive (they live inside unforced output thunks) —
    #    empty follows keeps the lock graph minimal; a future colmena
    #    bump that starts forcing them fails loudly (missing attr)
    #    instead of silently fetching something unpinned.
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
  # R31: everything the outputs body used to carry inline (the
  # host/darwin toplevel projections, the module-docs factory call,
  # the five repo-hygiene gates imported and merged, the pdsh
  # invocation, the tests import) lives producer-side now — the
  # linker pass (lib/shared/faces.nix) assembles the finished
  # artifacts onto the flake-protocol output names, and this file is
  # left with input registration and one line of delegation. The
  # layer map and the contract live in faces.nix's header.
  outputs = { self, ... }@inputs: import ./lib/shared/faces.nix { inherit self inputs; };
}
