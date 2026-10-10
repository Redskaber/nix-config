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
    # platform/nixos/core/base/disk.nix), never here — the entry layer
    # registers producers, it does not assemble consumers.
    disko.url = "https://github.com/nix-community/disko/archive/56ef5e72fec74b993ad0973b2dfa4eadeb48ba41.tar.gz";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Impermanence — declarative persistent state on ephemeral roots
    # (T5.14): the interpreter for hosts/<h>/persist.nix declarations.
    # Same registration story as disko above (capability registered
    # platform-side in platform/nixos/core/base/impermanence.nix, data
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
    # platform/nixos-wsl/default.nix (the thin door that reuses the
    # nixos customs); hosts/nixos-wsl/ carries the host's data.
    # Tarball-pinned to the release-26.05 branch (release branches
    # are nixpkgs-coupled since 2505.7.0 — main tracks unstable).
    # The module owns the WSL surface (wsl.conf generation, systemd
    # hosting, interop/binfmt, boot/kernel/loader subtraction); our
    # platform/nixos/core/base/wsl.nix keeps only the true deltas.
    nixos-wsl.url = "https://github.com/nix-community/NixOS-WSL/archive/b98199a76ab180be55f7a6a97bd4984a87c99964.tar.gz";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    # Nix types expend from my costum
    nix-types.url = "github:Redskaber/nix-types";

    # Nix dev Shell manager
    pdshell.url = "github:Redskaber/pdshell";
    pdshell.inputs.nixpkgs.follows = "nixpkgs";
    # pdshell builds its ContextPhase FSM on nix-types' enum — pin it to
    # OUR nix-types input so the dispatch tables and the FSM evaluate
    # against ONE rev (SSOT). Without this the lock graph keeps a second
    # nix-types_2 node that can silently drift on partial updates.
    pdshell.inputs.nix-types.follows = "nix-types";

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

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      ...
    }@inputs:
    let
      # ── Host→closure targets (T5.1) ─────────────────────────────
      # The compiler-shaped backend lives in lib/shared/targets.nix:
      # inventory → capability classification → target emitters. This
      # file only maps the finished products onto flake-protocol output
      # names — no host enumeration, no filters, no constructor calls
      # here (the entry layer stays declarative; the pipeline stages
      # belong to the producer).
      targets = import ./lib/shared/targets.nix {
        inherit
          self
          nixpkgs
          nixpkgs-unstable
          inputs
          ;
      };

      # ── Producer side (lib/shared) ───────────────────────────────
      # Base policy instance: two-phase init (schema/enum/fn/const →
      # runtime synthesis), host-scoped by default. Everything
      # flake-level consumes THIS handle; hosts get their own
      # policy-scoped instances inside lib/shared/targets.nix.
      # T5.10: the backend pass exports the base IR handle it already
      # builds (targets.base), so the flake level and the dispatch
      # layer read ONE instance instead of each paying for an
      # identical policy-graph construction.
      shared = targets.base;
      pkgs = shared.pkgs;
      devDir = shared.devDir;

      # T8.1: hoisted so tests/docs-ssot.nix can count shell names
      # without re-calling pdshells — one construction, two consumers
      # (the devShells output below and the docs-SSOT check).
      pdsh = shared.pdshells {
        inherit
          pkgs
          inputs
          shared
          devDir
          ;
      };

      # ── Test matrix, imported ONCE (T7.3) ─────────────────────
      # tests/default.nix returns two faces over the SAME member
      # thunks: the flat `checks` attrset (what checks.${system}
      # below consumes — one derivation per attr, exactly what
      # `nix flake check` expects) and the `planes` groups (the
      # taxonomy's own grouping, exposed via api.checks.planes so
      # CI hands a whole plane to nix-fast-build instead of
      # discovering members by name prefix and building them one
      # at a time). One import here = one evaluation; addressing a
      # member through either face adds nothing (T5.10 discipline).
      tests = import ./tests { inherit inputs shared; };
    in
    {
      # api
      api.inputs = inputs;
      api.shared = shared;
      api.targets = targets.inventory;
      # T7.3: the planes face of the test matrix.
      # `nix-fast-build --flake .#api.checks.planes.<plane>` is the
      # CI handoff point — the fragment resolves to an attrset of
      # derivations with the SAME shape as .#checks.${system}, so
      # nix-eval-jobs evaluates the plane in parallel and nix-fast-
      # build pipelines the builds (`--force-recurse` traversal,
      # verified against nix-fast-build 1.4.0 / nix-eval-jobs
      # 2.34.3, both bundled in the locked nixpkgs 26.05).
      api.checks.planes = tests.planes;

      # T8.2: the host-closure build face — the Linux system
      # toplevels, data-driven from the inventory (a new NixOS host
      # joins by construction). CI hands this whole face to
      # nix-fast-build for closure-level build depth (the Mic92-parity
      # move); darwin is aarch64-darwin and stays eval-only in CI —
      # building it needs a darwin runner or a cross toolchain.
      api.host-toplevels = builtins.listToAttrs (
        builtins.map (h: {
          name = h;
          value = targets.nixosConfigurations.${h}.config.system.build.toplevel;
        }) targets.inventory.nixosHosts
      );

      # debug information
      # Available through 'nix eval .#debug.test_system'
      debug.test_system = pkgs.stdenv.hostPlatform.system;
      debug.test_devDir = devDir;

      # checks
      # Test planes 0–5 + the two repo-hygiene gates: the pre-commit
      # eval gate (see tests/pre-commit.nix for the git-hooks half
      # and its history) and the docs-SSOT contract (tests/docs-ssot.nix,
      # T8.1 — README/test-matrix count anchors asserted against live
      # facts at BUILD time, which is why CI STAGE 1 builds both).
      # T7.3: the FLAT face only — `nix flake check` requires each
      # attribute here to be a derivation, so the planes grouping
      # lives behind api.checks.planes, never inside this output.
      checks.${shared.arch.tag} =
        tests.checks
        // (import ./tests/pre-commit.nix { inherit inputs self shared; })
        // (import ./tests/docs-ssot.nix {
          inherit
            inputs
            self
            shared
            tests
            ;
          inventory = targets.inventory;
          devShellNames = builtins.attrNames pdsh;
        });

      # Your custom packages
      # Accessible through 'nix build', 'nix shell', etc
      packages.${shared.arch.tag} = shared.packages // {
        # Options reference for the export/ modules (T5.3) — the doc
        # factory is producer-side (lib/shared/docs.nix); this is the
        # protocol-name mapping only.
        module-docs = import ./lib/shared/docs.nix {
          inherit
            self
            nixpkgs
            inputs
            ;
          arch = shared.arch.tag;
        };
      };
      # Your custom packages and patches, exported as overlays
      overlays = shared.overlays;
      # Formatter choices
      formatter.${shared.arch.tag} = pkgs.nixfmt;

      # Reusable nixos modules (T2.1) — standard flake output names.
      # These are usually stuff you would upstream into nixpkgs.
      nixosModules = import ./export/nixos;
      # Reusable home-manager modules — standard flake output names.
      # These are usually stuff you would upstream into home-manager.
      homeModules = import ./export/home;
      # Legacy aliases (pre-T2.1 attr names) kept for existing consumers.
      nixos = import ./export/nixos;
      home = import ./export/home;

      # devShells loader (T8.1: the pdsh construction lives in the
      # let above — hoisted once so the docs-SSOT check counts the
      # same attrset the output exposes)
      devShells.${shared.arch.tag} = pdsh;

      # ── Host closures — HOST-KEYED (T2.4), CAPABILITY-ROUTED (T4.0),
      # PRODUCED by lib/shared/targets.nix (T5.1) ────────────────────
      # 'sudo nixos-rebuild --flake <flake_path>#<host> switch'
      # Hosts are enumerated from hosts/ automatically; the legacy
      # username-platform alias keeps the pre-T2.4 attr reachable.
      inherit (targets) nixosConfigurations;
      # Standalone home-manager configuration entrypoints — per host
      # (T2.3): '<user>@<host>'. First: through 'nix build
      # .#homeConfigurations.<user>@<host>.activationPackage' &&
      # './result/activate'; available through 'home-manager --flake
      # .#<user>@<host>'.
      inherit (targets) homeConfigurations;
      # nix-darwin configuration entrypoints (T3.2): hosts/<h> whose
      # policy declares platform.tag = "darwin" are built through
      # nix-darwin instead of nixosSystem; the platform system
      # customs (platform/<tag>/default.nix — single live door, the
      # T5.8 fold; directory-as-domain, T5.11) carries the system
      # assembly with home-manager riding in module mode.
      # 'darwin-rebuild switch --flake .#<host>'.
      inherit (targets) darwinConfigurations;
    };
}
