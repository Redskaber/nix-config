# @path: ~/projects/nix-config/flake.nix
# @author: redskaber
# @datetime: 2025-12-12

{
  description = "Kilig's declarative development enviroment";

  inputs = {
    # Nixpkgs (url version)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Home Manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let in {
    
    # Standalone home-manager configuration entrypoint
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

