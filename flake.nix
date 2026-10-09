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
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

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

    # Zen-browser
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    # Sops-Nix
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Nix types expend from my costum
    nix-types.url = "github:Redskaber/nix-types";

    # Nix dev Shell manager
    pdshell.url = "github:Redskaber/pdshell";
    pdshell.inputs.nixpkgs.follows = "nixpkgs";

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

    # ── nix-darwin (T3.2): macOS system closure ─────────────────────
    # Tarball-pinned (github: short syntax would need API resolution;
    # the archive URL fetches directly and pins the exact rev).
    # Branch nix-darwin-26.05 — nix-darwin release-checks its branch
    # against the nixpkgs release it is built for (26.05 here); master
    # (26.11) would fail the eval-time assert.
    # Home-manager integrates in module mode via darwinModules.
    nix-darwin.url = "https://github.com/LnL7/nix-darwin/archive/c3e90c89649b07d1a96e4b9dd6cd0d6e44b91a74.tar.gz";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      ...
    }@inputs:
    let
      # User-Shared Config — base policy (the default host; checks/devShells/
      # packages stay on this instance).
      shared = import ./lib/shared {
        inherit
          self
          nixpkgs
          nixpkgs-unstable
          inputs
          ;
      };
      pkgs = shared.pkgs;
      devDir = shared.devDir;

      # ── Host inventory (T2.3/T2.4) ──────────────────────────────
      # Enumerated from hosts/ — adding a machine is mkdir + files, no
      # flake.nix edit. Each host gets its own policy-scoped `shared`
      # (base shared.nix ⊕ hosts/<host>/shared.nix overrides).
      hostNames = builtins.attrNames (
        pkgs.lib.filterAttrs (_: t: t == "directory") (builtins.readDir ./hosts)
      );
      mkShared =
        host:
        import ./lib/shared {
          inherit
            self
            nixpkgs
            nixpkgs-unstable
            inputs
            ;
          hostName = host;
        };
      mkNixos =
        host:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            shared = mkShared host;
          };
          modules = [ ./nixos ];
        };

      # ── Platform dispatch (T3.1/T3.2, T4.0 capability-routed) ───────
      # The hosts/ inventory is heterogeneous now: NixOS machines, a wsl
      # standalone-HM host and a darwin host link through DIFFERENT output
      # sections — same object graph, several target formats (a compiler
      # links one IR into multi-target artifacts; the flake links one
      # policy graph into nixos / darwin / standalone-HM closures).
      # T4.0: routing queries the platform capability table (enum.nix
      # caps vectors) instead of raw tag strings — the entry layer and
      # the leaves now read the SAME dispatch table, and a host changes
      # class by editing hosts/<h>/shared.nix, not this file.
      hostCaps = h: (mkShared h).caps;
      nixosHosts = builtins.filter (h: (hostCaps h).nixos-system) hostNames;
      darwinHosts = builtins.filter (h: (hostCaps h).darwin) hostNames;
      # Standalone home-manager stays meaningful on generic-Linux-class
      # tags; darwin hosts get their HM through the darwin module instead
      # (a darwin standalone closure would otherwise carry linux pkgs).
      standaloneHosts = builtins.filter (h: !(hostCaps h).darwin) hostNames;

      hostConfigs = builtins.listToAttrs (
        builtins.map (h: pkgs.lib.nameValuePair h (mkNixos h)) nixosHosts
      );
    in
    {
      # api
      api.inputs = inputs;
      api.shared = shared;

      # debug information
      # Available through 'nix eval .#debug.test_system'
      debug.test_system = pkgs.stdenv.hostPlatform.system;
      debug.test_devDir = devDir;

      # checks
      # NOTE(fix): git-hooks.nix removed the `nixfmt-rfc-style` hook alias —
      # its formatter merged into plain `nixfmt` (nixfmt ≥0.6 speaks RFC-116
      # style) — and `lib.<sys>.run` returns the check DERIVATION directly,
      # not `{ pre-commit-check }`. Merging it with `//` used to spill drv
      # attrs (outPath/drvPath/…) into checks and silently DROP the hook
      # entry from the output set (shallow CI eval never noticed). Assign it
      # under its proper attr name — `nix flake check --no-build` is the gate
      # that keeps this wiring honest.
      checks.${shared.arch.tag} = (import ./tests { inherit inputs shared; }) // {
        pre-commit-check = inputs.pre-commit-hooks.lib.${shared.arch.tag}.run {
          src = self;
          hooks = {
            nixfmt = {
              enable = true;
              excludes = [
                "flake.lock"
                ".*-config/.*"
              ];
            };
            statix.enable = true;
            # deadnix gates on dead `let` bindings (the real dead-code class).
            # `--no-lambda-pattern-names` / `--no-lambda-arg` exempt the
            # idiomatic signatures this tree standardises on: uniform module
            # heads ({ inputs, shared, lib, config, pkgs, ... }) and overlay
            # pairs (final: prev:).
            deadnix = {
              enable = true;
              settings = {
                noLambdaPatternNames = true;
                noLambdaArg = true;
              };
            };
          };
        };
      };

      # Your custom packages
      # Accessible through 'nix build', 'nix shell', etc
      packages.${shared.arch.tag} = shared.packages;
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

      # devShells loader
      devShells.${shared.arch.tag} = shared.pdshells {
        inherit
          pkgs
          inputs
          shared
          devDir
          ;
      };

      # NixOS configuration entrypoints — HOST-KEYED (T2.4)
      # 'sudo nixos-rebuild --flake <flake_path>#<host> switch'
      # Hosts are enumerated from hosts/ automatically; the legacy
      # username-platform alias keeps the pre-T2.4 attr reachable.
      nixosConfigurations = hostConfigs // {
        "${shared.user.username}-${shared.platform.tag}" = hostConfigs.${shared.hostName};
      };

      # Standalone home-manager configuration entrypoints — per host
      # (T2.3): '<user>@<host>' — the host-scoped shared flows into the
      # same platform tree, so the second machine gets its own sets too.
      # First: through 'nix build .#homeConfigurations.<user>@<host>.activationPackage' && './result/activate'
      # Available through 'home-manager --flake .#<user>@<host>'
      homeConfigurations = builtins.listToAttrs (
        builtins.map (
          h:
          let
            hshared = mkShared h;
          in
          pkgs.lib.nameValuePair "${hshared.user.username}@${h}" (
            home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              extraSpecialArgs = {
                inherit inputs;
                shared = hshared;
              };
              modules = [ ./platform/${hshared.platform.tag} ];
            }
          )
        ) standaloneHosts
      );

      # ── Darwin entrypoints (T3.2) ──────────────────────────────────
      # hosts/<h> whose policy declares platform.tag = "darwin" are built
      # through nix-darwin instead of nixosSystem. Home-manager rides in
      # via home-manager.darwinModules.home-manager (module mode): one
      # activation path, darwin-native. Evaluation of the darwin closure
      # is exercised from any builder platform; 'switch' itself needs a
      # macOS host (darwin-rebuild switch --flake .#<host>).
      darwinConfigurations = builtins.listToAttrs (
        builtins.map (
          h:
          let
            dshared = mkShared h;
          in
          pkgs.lib.nameValuePair h (
            inputs.nix-darwin.lib.darwinSystem {
              system = dshared.arch.tag;
              specialArgs = {
                inherit inputs;
                shared = dshared;
              };
              modules = [
                inputs.home-manager.darwinModules.home-manager
                ./darwin
              ];
            }
          )
        ) darwinHosts
      );
    };
}
