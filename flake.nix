# @path: ~/projects/nix-config/flake.nix
# @author: redskaber
# @datetime: 2025-12-12
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html

{
  description = "Kilig(Redskaber)'s declarative development environment";

  inputs = {
    # Nixpkgs (url version)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    # NUR (Nix User Repositories)
    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Neovim Config
    nvim-config.url = "github:Redskaber/nvim-config";
    nvim-config.flake = false;

    # Starship Config
    starship-config.url = "github:Redskaber/starship-config";
    starship-config.flake = false;

    # Wezterm Config
    wezterm-config.url = "github:Redskaber/wezterm-config";
    wezterm-config.flake = false;

    # Tmux-Config
    tmux-config.url = "github:Redskaber/tmux-config";
    tmux-config.flake = false;

    # Mpv-config
    # mpv-config.url = "github:Redskaber/mpv-config";
    # mpv-config.flake = false;

    # Vscode-config
    vscode-config.url = "github:Redskaber/vscode-config";
    vscode-config.flake = false;

  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
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

    # TODO: Need Hooks System ?
    # Helper: load all dev modules for a system
    devShellsForSystem = system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      import ./lib/dev-shells.nix {
        inherit pkgs inputs;
        suffix = ".nix";
        devDir = ./home-manager/dev;
      };
  in {
    # debug information
    # Available through 'nix eval .#debug.test_forAllSystems'
    debug.test_forAllSystems = forAllSystems (system: "Hello from ${system}");

    # Your custom packages
    # Accessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    homeManagerModules = import ./modules/home-manager;

    # Your custom dev shells
    # devShells = forAllSystems( system: {
    # default = let
    #   pkgs = nixpkgs.legacyPackages.${system};
    # in
    #   pkgs.mkShell {
    #     buildInputs = with pkgs; [
    #       cargo rustc rustfmt clippy rust-analyzer
    #       # (explicit optional) depends
    #       glib
    #     ];
    #     # (explicit optional) build depends packages config inject
    #     nativeBuildInputs = [ pkgs.pkg-config ];
    #     # env.RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
    #     shellHook = ''
    #       export RUST_SRC_PATH=${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}
    #     '';
    #   };
    # });
    # devShells loader
    devShells = forAllSystems devShellsForSystem;

    # TODO: function handler homeConfigurations, dynamic generates etc.
    # Standalone home-manager configuration entrypoint
    # First: through 'nix build .#homeConfigurations.your-username@hostname.activationPackage' && './result/activate'
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = {
      # FIXME replace with your username@hostname
      "kilig@extensa" = home-manager.lib.homeManagerConfiguration {
        # Home-manager requires 'pkgs' instance
        # FIXME replace x86_64-linux with your architecure
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs; };
        # > Out main home-manager configuration file <
        modules = [ ./home-manager/home.nix ];
      };
    };
  };
}

