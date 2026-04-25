# @path: ~/projects/configs/nix-config/flake.nix
# @author: redskaber
# @datetime: 2025-12-12
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# TODO: mutil-pal gl app transparent proxy choice version.
# - Tips: formatter and devShells need arch-name for sub-keyname,(else cachk error)

{
  description = "Kilig(Redskaber)'s declarative development environment";

  # TODO: waiting design flake-dep-manager handle inputs
  inputs = {
    # Nixpkgs (url version)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
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
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

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

    # Wechat
    wechat.url = "github:Redskaber/wechat";
    wechat.inputs.nixpkgs.follows = "nixpkgs";

    # Unpryc
    unrpyc.url = "github:Redskaber/unrpyc";
    unrpyc.inputs.nixpkgs.follows = "nixpkgs";

    # CNMPlayer (china area use)
    cnmplayer.url = "github:Redskaber/cnmplayer";
    cnmplayer.inputs.nixpkgs.follows = "nixpkgs";

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
      # User-Shared Config
      shared = import ./lib/shared { inherit nixpkgs nixpkgs-unstable inputs; };
      pkgs = shared.pkgs;
      devDir = shared.devDir;
    in
    {
      # api
      api.inputs = inputs;

      # debug information
      # Available through 'nix eval .#debug.test_shared'
      debug.test_shared = shared;
      debug.test_user_shared = shared._user_shared;
      debug.test_system = pkgs.stdenv.hostPlatform.system;
      debug.test_devDir = devDir;
      debug.test_nix-types = inputs.nix-types;
      debug.test_pdshell = inputs.pdshell;

      # Your custom packages
      # Accessible through 'nix build', 'nix shell', etc
      packages = import ./pkgs pkgs;
      # Your custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };
      # Formatter choices
      formatter.${shared.arch.tag} = pkgs.nixfmt;

      # Reusable nixos modules you might want to export
      # These are usually stuff you would upstream into nixpkgs
      nixos = import ./export/nixos;
      # Reusable home-manager modules you might want to export
      # These are usually stuff you would upstream into home-manager
      home = import ./export/home;

      # devShells loader
      devShells.${shared.arch.tag} = import inputs.pdshell.pdshells {
        inherit
          pkgs
          inputs
          shared
          devDir
          ;
      };

      # NixOS configuration entrypoint
      # First used(root): 'nixos-install --flake <flake_path>#your-hostname switch'
      # Available through: 'sudo nixos-rebuild --flake <flake_path>#your-hostname switch'
      nixosConfigurations = {
        "${shared.user.username}-${shared.platform.tag}" = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs shared; };
          modules = [ ./nixos ];
        };
      };

      # TODO: function handler homeConfigurations, dynamic generates etc.
      # Standalone home-manager configuration entrypoint
      # First: through 'nix build .#homeConfigurations.your-username@hostname.activationPackage' && './result/activate'
      # Available through 'home-manager --flake .#your-username@your-hostname'
      homeConfigurations = {
        "${shared.user.username}@${shared.platform.tag}" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs shared; };
          modules = [ ./home/hosts/${shared.platform.tag} ];
        };
      };
    };
}
