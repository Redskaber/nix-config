# @path: ~/projects/nix-config/home-manager/home.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml


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
    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    ./app/git.nix
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
    stateVersion = "25.11";
  };
 
  # Add stuff for your user as you see fit:
  home.packages = with pkgs; [
    curl wget gnupg git
    htop tmux bat eza tree
    gdb valgrind strace ltrace
    neovim
    zsh fzf ripgrep fd
    # fonts
    nerd-fonts.jetbrains-mono
    noto-fonts-color-emoji
  ];
  # home-manager:
  programs.home-manager.enable = true;
  # fonts:
  # enable -> ~/.local/share/fonts/*
  fonts.fontconfig.enable = true;
  fonts.fontconfig.defaultFonts.monospace = [ "JetBrainsMono Nerd Font" ];
  fonts.fontconfig.defaultFonts.emoji = [ "Noto Color Emoji" ];
  

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}

 
