# @path: ~/projects/configs/nix-config/flake.nix
# @author: redskaber
# @datetime: 2025-12-12
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# TODO: mutil-pal gl app transparent proxy choice version.


{
  description = "Kilig(Redskaber)'s declarative development environment";

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

    # Ren'Py
    # Unpryc
    unrpyc.url = "github:Redskaber/unrpyc";

    # Neovim Config
    nvim-config.url = "github:Redskaber/nvim-config";
    nvim-config.flake = false;

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

    # Vscode-config
    vscode-config.url = "github:Redskaber/vscode-config";
    vscode-config.flake = false;

    # Mpv-config
    mpv-config.url = "github:Redskaber/mpv-config";
    mpv-config.flake = false;

    # Btop-config
    btop-config.url = "github:Redskaber/btop-config";
    btop-config.flake = false;

    # Cava-config
    cava-config.url = "github:Redskaber/cava-config";
    cava-config.flake = false;

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

  };

  outputs =
  {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs:
    let
      # Supported systems for your flake packages, shell, etc.
      systems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      # This is a function that generates an attribute by calling a function you
      # pass to it, with each system as an argument
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # User-Shared Config
      shared = import ./lib/shared;

      # Helper: load all dev modules for a system
      devShellsForSystem = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          devDir = ./home/core/dev;
        in
        import ./lib/dev/pdshells.nix { inherit pkgs inputs devDir; };
    in
  {
    # debug information
    # Available through 'nix eval .#debug.test_forAllSystems'
    debug.test_forAllSystems = forAllSystems (system: "Hello from ${system}");
    debug.test_shared = shared;

    # Your custom packages
    # Accessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays { inherit inputs; };

    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixos = import ./export/nixos;
    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    home = import ./export/home;

    # devShells loader
    # USAGE: auto-read and lazy-load
    #   default-dev-root:
    #     ./home/core/dev/
    #   mode:
    #     dirmode | filemode
    #   show:
    #     nix falke show  -> devShells (existed fullnames)
    #   used:
    #     nix develop <flake.nix-path>#<fullname>
    #     # or used profile
    #     nix develop <profile-path>         # from `nix develop <flake-path>#<fullname> --profile <profile-save-path>`
    # More: read ./lib/dev
    devShells = forAllSystems devShellsForSystem;

    # NixOS configuration entrypoint
    # First used(root): 'nixos-install --flake <flake_path>#your-hostname switch'
    # Available through: 'sudo nixos-rebuild --flake <flake_path>#your-hostname switch'
    nixosConfigurations = {
      "${shared.user.username}-${shared.hostName}" = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs shared; };
        # > Our main nixos configuration file <
        modules = [ ./nixos/configuration.nix ];
      };
    };

    # TODO: function handler homeConfigurations, dynamic generates etc.
    # Standalone home-manager configuration entrypoint
    # First: through 'nix build .#homeConfigurations.your-username@hostname.activationPackage' && './result/activate'
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = {
      "${shared.user.username}@${shared.hostName}" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${shared.arch};
        extraSpecialArgs = { inherit inputs shared; };
        modules = [ ./home/hosts/${shared.hostName}.nix ];
      };
    };
  };
}


