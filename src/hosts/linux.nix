# @path: ~/projects/configs/nix-config/src/hosts/linux.nix
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

  # linux non-nixos environment inject
  targets.genericLinux = {
    enable = true;
    nixGL = {
      packages = inputs.nixgl.packages;
      defaultWrapper = "mesa";
      offloadWrapper = "mesaPrime";
    };
  };

  # You can import other home-manager modules here
  imports = [
    # If you import other home-manager modules from other flakes (such as nix-colors):
    # You can also split up your configuration and import pieces of it here:
    ./srv/mako.nix

    ./sys/atuin.nix
    ./sys/direnv.nix
    ./sys/fonts.nix
    ./sys/git.nix
    ./sys/starship.nix
    ./sys/zsh.nix
    ./sys/fish.nix
    ./sys/fastfetch.nix
    ./sys/zoxide.nix

    ./app/kitty.nix
    ./app/nvim.nix
    ./app/qq.nix
    ./app/rbw.nix
    ./app/steam.nix
    ./app/tmux.nix
    ./app/vscode.nix
    ./app/wechat.nix
    ./app/wezterm.nix

    # devShells: import dev/lang.nix from flake.nix
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
    # network utils
    curl wget gnupg git bottom tree
    gdb valgrind strace ltrace
    # Terminal prompt shell
    # wezterm (wrapper->nixgl) kitty (wrapper->nixgl)
    starship zsh fish
    # find and tools
    fzf ripgrep fd bat eza delta yazi zoxide
    # session
    tmux
    # env auto-switching
    direnv nix-direnv
    # fonts
    nerd-fonts.jetbrains-mono
    noto-fonts-color-emoji
    # social
    # qq wechat mpv steam
    # dev
    # c/c++,rust,js/ts,python,lua,nix,...
  ];

  # home-manager:
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}


