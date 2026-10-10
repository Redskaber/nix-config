# @path: ~/projects/configs/nix-config/lib/shared/lang/enum.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: lib::shared::enum
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html

{ inputs, ... }:
let
  inherit (inputs.nix-types.lib) enum;

  editor = enum "editor" [
    "vim"
    "nvim"
    "code"
    "zeditor"
  ];
  version = enum "version" {
    v25_11 = {
      stateVersion = "25.11";
      wine = pkgs: pkgs.wineWowPackages.waylandFull;
      swww = pkgs: pkgs.swww;
      adb = {
        programs.adb.enable = true;
      };
    };
    v26_05 = {
      stateVersion = "26.05";
      wine = pkgs: pkgs.wineWow64Packages.waylandFull;
      swww = pkgs: pkgs.awww;
      adb = { };
    };
  };
  # Shared strategy payloads for the Linux-family platform rows (DRY):
  # one definition, three references — the rows stay diffable, the
  # behaviour stays single-sourced.
  strategies = {
    home-prefix = "/home";
    btop =
      pkgs:
      pkgs.btop.override {
        # Linux GPU introspection — darwin takes the stock build (darwin
        # GPU reporting works out of the box).
        rocmSupport = true;
        cudaSupport = true;
      };
    trace-tools =
      scope: with scope; [
        valgrind
        strace
        ltrace
        pciutils
        vulkan-tools
      ];
  };

  # ── Platform dispatch table (T4.0) ─────────────────────────────────
  #
  # The distribution layer for platform semantics. Each member carries:
  #
  #   caps        — capability vector: the resolved facts leaves consume
  #                 (never a raw tag comparison, never a re-derived
  #                 predicate call at the leaf).
  #   home-prefix — data for fn.homeDir (no branching, just interpolation).
  #   btop        — per-platform package strategy (version.wine/swww
  #                 precedent): Linux family takes the GPU-stack build,
  #                 darwin takes stock.
  #   trace-tools — Linux introspection/tracing toolbelt for env/base
  #                 (Null-Object row on darwin: an empty list, not an
  #                 absent one — consumers stay unconditional).
  #
  # Compiler pipeline view: this table is the target description ONE pass
  # reads; leaves are codegen that only queries resolved facts. Adding a
  # platform = writing ONE row here (open/closed); adding a capability
  # dimension = one column, every row forced to answer it (exhaustive
  # by construction, like nix-types match).
  linux = {
    caps = {
      linux-family = true; # runs the Linux userland stack
      nixos-system = false; # no NixOS system layer on this host
      wsl = false;
      darwin = false;
    };
    inherit (strategies) home-prefix btop trace-tools;
  };
  darwin = {
    caps = {
      linux-family = false; # Aqua/darwin userland — no Linux stack
      nixos-system = false;
      wsl = false;
      darwin = true; # launchd/nix-darwin owns system-level activation
    };
    home-prefix = "/Users";
    btop = pkgs: pkgs.btop; # stock build (Aqua GPUs report out of the box)
    trace-tools = _: [ ]; # Null-Object: dtrace/lldb own that land
  };
  nixos = {
    caps = {
      linux-family = true;
      nixos-system = true; # the NixOS system layer owns i18n/sops/…
      wsl = false;
      darwin = false;
    };
    inherit (strategies) home-prefix btop trace-tools;
  };
  wsl = {
    caps = {
      linux-family = true; # Linux userland inside the Windows kernel interface
      nixos-system = false;
      wsl = true; # interop + dual-kernel clock-drift realities
      darwin = false;
    };
    inherit (strategies) home-prefix btop trace-tools;
  };
  # NixOS-WSL (T7.1): the NixOS system form hosted inside a WSL2
  # distro — a full NixOS system layer that runs under the Windows
  # host's kernel. A fifth row, not a mutation of `nixos`: capability
  # cells the plain nixos row answers false are answered true here
  # (wsl), and the customs that row selects (platform/nixos-wsl/ —
  # the nixos customs + the NixOS-WSL interpreter) differ from the
  # bare-metal ones the way the caps differ. The sibling `wsl` row
  # stays what it was: a WSL distro whose system layer this flake
  # does NOT own (standalone HM only, hosts/wsl).
  nixos-wsl = {
    caps = {
      linux-family = true;
      nixos-system = true; # the NixOS system layer, WSL-hosted
      wsl = true; # interop + dual-kernel clock-drift realities
      darwin = false;
    };
    inherit (strategies) home-prefix btop trace-tools;
  };
  platform = enum "platform" {
    inherit
      linux
      darwin
      nixos
      wsl
      nixos-wsl
      ;
  };
  arch = enum "arch" [
    "aarch64-darwin"
    "aarch64-linux"
    "i686-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];

  # strategy
  portal = enum "portal" {
    gnome = {
      default = [ "gtk" ];
      extraPortals = (pkgs: with pkgs; [ xdg-desktop-portal-gtk ]);
      wlr = false;
    };
    niri = {
      default = [
        "wlr"
        "gtk"
      ];
      extraPortals = (
        pkgs: with pkgs; [
          xdg-desktop-portal-wlr
          xdg-desktop-portal-gtk
        ]
      );
      wlr = true;
    };
    hyprland = {
      default = [
        "hyprland"
        "gtk"
      ];
      extraPortals = (pkgs: with pkgs; [ xdg-desktop-portal-gtk ]);
      wlr = false;
    };
    # Null-Object portal (T3.1/T3.2): headless / non-Linux-WM platforms
    # (wsl console, darwin Aqua) route here so downstream consumers stay
    # unconditional — the absence of a windowing stack is expressed as a
    # strategy value, not as call-site conditionals.
    none = {
      default = [ ];
      extraPortals = (pkgs: [ ]);
      wlr = false;
    };
    # Tips: xdg-desktop-portal-hyprland used input new version
  };
  window-manager = enum "windowManager" {
    gnome = {
      portal = portal.gnome;
      # T4.0: capability bit — a real desktop session exists (portal
      # mediation meaningful). Leaves read the resolved fact instead of
      # comparing `.tag != "none"` strings.
      desktop-session = true;
    };
    niri = {
      portal = portal.niri;
      desktop-session = true;
    };
    hyprland = {
      portal = portal.hyprland;
      desktop-session = true;
    };
    # Null-Object member (T3.1/T3.2): lets platform/darwin and platform/wsl
    # import ../../../home/wm unconditionally — the router dispatches to an
    # empty implementation instead of the platform file special-casing
    # the import list. Adding a member here is the open/closed move; no
    # existing consumer changes.
    none = {
      portal = portal.none;
      desktop-session = false; # no Linux desktop session (wsl console / Aqua)
    };
  };

  display-manager = enum "displayManager" [
    "gdm"
    "lemurs"
    "ly"
    "sddm"
    # T7.1: the Null-Object row — no display manager. Console hosts
    # (WSL, headless servers) select it; platform/nixos/dm/none/ is
    # the deliberately-empty module that keeps the dm router
    # unconditional (same pattern as window-manager none).
    "none"
  ];
  # drive           = enum "drive"          [ "amd" "intel" "nvidia" "nvidia-prime" ];
  drive-group = enum "driveGroup" {
    amd = [ "amd" ];
    intel = [ "intel" ];
    nvidia = [ "nvidia" ];
    nvidia-prime = [ "nvidia-prime" ];
    amd-nvidia = [
      "amd"
      "nvidia"
    ];
    amd-nvidia-prime = [
      "amd"
      "nvidia-prime"
    ];
    intel-nvidia = [
      "intel"
      "nvidia"
    ];
    intel-nvidia-prime = [
      "intel"
      "nvidia-prime"
    ];
  };
  # T4.1: the shell enum carries its HM integration truth table as DATA
  # (platform-caps pattern): every row answers all three integration
  # bits, so adding a shell = ONE row here instead of three `.tag ==`
  # comparisons re-derived in the runtime layer. The eight HM modules
  # keep consuming the published resolved facts unchanged
  # (programs.<t> = shared.shellIntegrations // { … }).
  shell = enum "shell" {
    bash = {
      integrations = {
        enableBashIntegration = true;
        enableZshIntegration = false;
        enableFishIntegration = false;
      };
    };
    zsh = {
      integrations = {
        enableBashIntegration = false;
        enableZshIntegration = true;
        enableFishIntegration = false;
      };
    };
    fish = {
      integrations = {
        enableBashIntegration = false;
        enableZshIntegration = false;
        enableFishIntegration = true;
      };
    };
  };

  # Application sets (multi-select routing, same pattern as drive-group)
  editor-set = enum "editorSet" {
    minimal = {
      editors = [ "nvim" ];

    };
    full-ai = {
      editors = [
        "nvim"
        "vscode"
        "cursor"
        "zed"
      ];
    };
    dev = {
      editors = [
        "nvim"
        "vscode"
        "cursor"
        "zed"
        "emacs"
        "kiro"
      ];
    };
    full = {
      editors = [
        "nvim"
        "vscode"
        "cursor"
        "zed"
        "emacs"
        "kiro"
        "trae"
        "zcode"
      ];
    };
  };
  terminal-set = enum "terminalSet" {
    kitty-only = {
      terminals = [ "kitty" ];
    };
    wezterm-only = {
      terminals = [ "wezterm" ];
    };
    both = {
      terminals = [
        "kitty"
        "wezterm"
      ];
    };
  };
  browser-set = enum "browserSet" {
    chrome-only = {
      browsers = [ "google-chrome" ];
    };
    qutebrowser = {
      browsers = [ "qutebrowser" ];
    };
    cli-only = {
      browsers = [ "w3m" ];
    };
    chrome-qute = {
      browsers = [
        "google-chrome"
        "qutebrowser"
      ];
    };
    all = {
      browsers = [
        "google-chrome"
        "qutebrowser"
        "w3m"
      ];
    };
  };

  # Application set: which app trees a host's home MERGES (T5.10 —
  # demand-driven module loading). The one weight axis the policy
  # graph was missing: editor/browser/terminal sets answer "which
  # leaves within a routed category"; this set answers "which
  # category TREES exist for the host at all" — lean machines stop
  # merging (and installing) desktop grab-bag modules they never
  # asked for, instead of paying the module-system fixed cost and
  # carrying unconditional packages (pre-T5.10 a console wsl host
  # and a lean darwin laptop both installed prismlauncher, wps and
  # blender).
  #
  # Row payloads list home/core/exp/app/ category DIRECTORIES; the
  # router is `builtins.map (c: ./${c}) shared.appCategories` — same
  # mode-B shape as the browser/editor/terminal routers.
  #
  # The triad rides every row: browser/editor/terminal are themselves
  # set-routed (their own sets prune the leaves), so the categories
  # are mandatory — "none" means "no grab-bag trees", never "no
  # editor at all".
  #
  # ORDER IS LOAD-BEARING: the module-system merges imports in list
  # order, `home.packages` concatenates in merge order, and the drv
  # hash of the full host pins to the resulting closure. The `full`
  # row therefore reproduces the pre-T5.10 static import list of
  # home/core/exp/app/default.nix EXACTLY (alphabetical); the enum
  # test (tests/lib/shared/lang/enum.nix) enforces it — reorder the
  # row and the test fails before hashes drift mysteriously.
  #
  # NOT here: home/core/exp/sys/* — the CLI toolbelt is the always-on
  # layer every host character consumes (console wsl IS the toolbelt
  # use case); the weight axis doesn't differentiate it, so it stays
  # unconditional. Platform-desktop vs cross-platform differences
  # inside a kept tree stay leaf-level caps gates (linux-family),
  # resolved facts, not re-derived predicates.
  app-set = enum "appSet" {
    # The desktop workstation: every app tree rides.
    full = {
      categories = [
        "browser"
        "dl"
        "editor"
        "fm"
        "game"
        "im"
        "image"
        "misc"
        "model"
        "music"
        "note"
        "office"
        "re"
        "reader"
        "terminal"
        "video"
      ];
    };
    # Terminal-shaped machine (the darwin laptop): the set-routed
    # triad + document/reading/reverse-engineering trees — the
    # cross-platform tooling that survives a "lean, terminal-shaped"
    # character. Desktop entertainment trees (game/im/model/note/
    # video/dl/fm/music) don't; the linux-only leaves inside kept
    # trees (gimp, wps, imv, unoconv) self-gate on linux-family.
    lean = {
      categories = [
        "browser"
        "editor"
        "image"
        "misc"
        "office"
        "re"
        "reader"
        "terminal"
      ];
    };
    # Null-Object row (console machines): the set-routed triad only
    # — whatever editor/browser/terminal sets the host declares,
    # nothing else from the app tree.
    none = {
      categories = [
        "browser"
        "editor"
        "terminal"
      ];
    };
  };

  # Service profile: controls install vs autostart for databases and virtualization
  service-profile = enum "serviceProfile" {
    full-autostart = {
      db = {
        postgresql = {
          install = true;
          autostart = true;
        };
        mysql = {
          install = true;
          autostart = true;
        };
        redis = {
          install = true;
          autostart = true;
        };
        mongodb = {
          install = true;
          autostart = true;
        };
      };
      virt = {
        libvirtd = {
          install = true;
          autostart = true;
        };
        incus = {
          install = true;
          autostart = true;
        };
        waydroid = {
          install = true;
          autostart = true;
        };
        podman = {
          install = true;
          autostart = true;
        };
      };
      # T3.4 observability: full workstation stack — every exporter,
      # plus the loki+grafana observability pair (README roadmap item).
      monitor = {
        enable = true;
        exporters = [
          "node"
          "postgres"
          "redis"
          "mysqld"
          "mongodb"
        ];
        loki = true;
        grafana = true;
      };

    };
    dev-on-demand = {
      db = {
        postgresql = {
          install = true;
          autostart = false;
        };
        mysql = {
          install = true;
          autostart = false;
        };
        redis = {
          install = true;
          autostart = false;
        };
        mongodb = {
          install = true;
          autostart = false;
        };
      };
      virt = {
        libvirtd = {
          install = true;
          autostart = false;
        };
        incus = {
          install = false;
          autostart = false;
        };
        waydroid = {
          install = false;
          autostart = false;
        };
        podman = {
          install = true;
          autostart = true;
        };
      };
      # T3.4 observability: dev box — node exporter only (resource
      # footprint matters; db services are on-demand anyway).
      monitor = {
        enable = true;
        exporters = [ "node" ];
        loki = false;
        grafana = false;
      };

    };
    server-pg-only = {
      db = {
        postgresql = {
          install = true;
          autostart = true;
        };
        mysql = {
          install = false;
          autostart = false;
        };
        redis = {
          install = false;
          autostart = false;
        };
        mongodb = {
          install = false;
          autostart = false;
        };
      };
      virt = {
        libvirtd = {
          install = false;
          autostart = false;
        };
        incus = {
          install = false;
          autostart = false;
        };
        waydroid = {
          install = false;
          autostart = false;
        };
        podman = {
          install = true;
          autostart = true;
        };
      };
      # T3.4 observability: server — collect metrics for the services
      # this profile actually runs (postgres); central infra scrapes.
      monitor = {
        enable = true;
        exporters = [
          "node"
          "postgres"
        ];
        loki = false;
        grafana = false;
      };

    };
    minimal = {
      db = {
        postgresql = {
          install = false;
          autostart = false;
        };
        mysql = {
          install = false;
          autostart = false;
        };
        redis = {
          install = false;
          autostart = false;
        };
        mongodb = {
          install = false;
          autostart = false;
        };
      };
      virt = {
        libvirtd = {
          install = false;
          autostart = false;
        };
        incus = {
          install = false;
          autostart = false;
        };
        waydroid = {
          install = false;
          autostart = false;
        };
        podman = {
          install = false;
          autostart = false;
        };
      };
      # T3.4 observability: off — minimal machines stay minimal.
      monitor = {
        enable = false;
        exporters = [ ];
        loki = false;
        grafana = false;
      };
    };
  };

  pointer-cursor = enum "pointerCursor" [
    "Bibata-Modern-Amber"
    "Bibata-Modern-Amber-Right"
    "Bibata-Modern-Classic"
    "Bibata-Modern-Classic-Right"
    "Bibata-Modern-Ice"
    "Bibata-Modern-Ice-Right"
    "Bibata-Original-Amber"
    "Bibata-Original-Amber-Right"
    "Bibata-Original-Classic"
    "Bibata-Original-Classic-Right"
    "Bibata-Original-Ice"
    "Bibata-Original-Ice-Right"
  ];

in
{
  inherit
    editor
    version
    platform
    arch
    window-manager
    display-manager
    drive-group
    shell
    editor-set
    terminal-set
    browser-set
    app-set
    service-profile
    pointer-cursor
    ;
}
