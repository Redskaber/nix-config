# @path: ~/projects/nix-config/home-manager/home.nix
# @author: redskaber
# @datetime: 2025-12-12


# This is your home-manager configuration file
# Use this to configure your home environment (it replace ~/.config/nixpkgs/home.nix)
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you import other home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModule

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      inputs.self.overlays.additions
      inputs.self.overlays.modifications
      inputs.self.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };
  
  # TODO: Set your username
  home = {
    username = "kilig";
    homeDirectory = "/home/kilig";
  };
 
  # Add stuff for your user as you see fit:
  home.packages = with pkgs; [ 
    git
    neovim
    htop
  ];
  
  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
      user.name = "redskaber";
      user.email = "redskaber@foxmail.com";
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}

 
