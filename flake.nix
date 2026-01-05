# @path: ~/projects/nix-config/flake.nix
# @author: redskaber
# @datetime: 2025-12-12
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html

{
  description = "Kilig's declarative development environment";

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
    nvim-config = {
      url = "github:Redskaber/nvim-config";
      flake = false;
    };

    # Starship Config
    starship-config = {
      url = "github:Redskaber/starship-config";
      flake = false;
    };

    # Wezterm Config
    wezterm-config = {
      url = "github:Redskaber/wezterm-config";
      flake = false;
    };

    # Tmux-Config
    tmux-config = {
      url = "github:Redskaber/tmux-config";
      flake = false;
    };

    # Mpv-config
    # mpv-config = {
    #   url = "github:Redskaber/mpv-config";
    #   flake = false;
    # };

    # Vscode-config
    vscode-config = {
      url = "github:Redskaber/vscode-config";
      flake = false;
    };
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

    # Helper: load all dev modules for a system
    devShellsForSystem = system:
    let
      suffix = ".nix";
      default = "default";

      pkgs = nixpkgs.legacyPackages.${system};
      devDir = ./home-manager/dev;
      devFiles = builtins.attrNames (builtins.readDir devDir);
      nixFiles = builtins.filter (name: pkgs.lib.hasSuffix suffix name) devFiles;

      # Load each raw dev module: e.g., rust.nix -> { default = ...; }
      rawModules = pkgs.lib.genAttrs nixFiles (file:
        import "${devDir}/${file}" { inherit pkgs inputs; }
      );

      # Normalize: ensure every module has at least 'default'
      # Also extract just the 'default' shell for merging
      # Rename keys and validate: lang.nix -> lang = { default = ...; }
      normalizedModules = pkgs.lib.mapAttrs' (fileName: mod:
      let
        lang = pkgs.lib.removeSuffix suffix fileName;
      in
        if pkgs.lib.isAttrs mod && pkgs.lib.hasAttr default mod
        then pkgs.lib.nameValuePair lang mod
        else throw "Module ${fileName} does not export a 'default' attribute"
      ) rawModules;

      # Extract the actual shell derivation for each language
      langShells = pkgs.lib.mapAttrs (lang: mod: mod.default) normalizedModules;

      # Merge all defaults into one global shell
      allDefaultShells = builtins.attrValues langShells;
      mergedInputs = pkgs.lib.unique (pkgs.lib.concatLists (map (s: s.buildInputs or []) allDefaultShells));
      mergedNative = pkgs.lib.unique (pkgs.lib.concatLists (map (s: s.nativeBuildInputs or []) allDefaultShells));
      mergedHooks = pkgs.lib.concatStringsSep "\n" (map (s: s.shellHook or "") allDefaultShells);

      globalDefault = pkgs.mkShell {
        buildInputs = mergedInputs;
        nativeBuildInputs = mergedNative;
        shellHook = mergedHooks;
      };

      # Final devShells for this system:
      # - Each language is available by name (e.g., rust, python)
      # - Plus a 'default' that merges all
    in langShells // { default = globalDefault; };
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

