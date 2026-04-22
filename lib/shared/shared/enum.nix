# @path: ~/projects/configs/nix-config/lib/shared/enum.nix
# @author: redskaber
# @datetime: 2026-04-23
# @discription: lib::shared::enum
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html


{ inputs, ... }:
let
  inherit (inputs.nix-types.enum) enum;

  editor    = enum "editor"   [ "vim" "nvim" "code" "zeditor" ];
  version   = enum "version"  {
    v25_11  = "25.11";
  };
  platform        = enum "platform"       [ "linux" "macos" "nixos" "wsl" ];
  arch            = enum "arch"           [ "aarch64-darwin" "aarch64-linux" "i686-linux" "x86_64-darwin" "x86_64-linux" ];

  # strategy
  portal          = enum "portal"        {
    gnome         = { default = [ "gtk"            ]; extraPortals = (pkgs: with pkgs; [ xdg-desktop-portal-gtk ]); wlr = false; };
    niri          = { default = [ "wlr" "gtk"      ]; extraPortals = (pkgs: with pkgs; [ xdg-desktop-portal-wlr xdg-desktop-portal-gtk ]); wlr = true;  };
    hyprland      = { default = [ "hyprland" "gtk" ]; extraPortals = (pkgs: with pkgs; [ xdg-desktop-portal-gtk ]); wlr = false; };
    # Tips: xdg-desktop-portal-hyprland used input new version
  };
  window-manager  = enum "windowManager" {
    gnome         = { portal = portal.gnome;    };
    niri          = { portal = portal.niri;     };
    hyprland      = { portal = portal.hyprland; };
  };

  display-manager = enum "displayManager" [ "gdm" "lemurs" "ly" "sddm" ];
  # drive           = enum "drive"          [ "amd" "intel" "nvidia" "nvidia-prime" ];
  drive-group     = enum "driveGroup"     {
    amd               = [ "amd" ];
    intel             = [ "intel" ];
    nvidia            = [ "nvidia" ];
    nvidia-prime      = [ "nvidia-prime" ];
    amd-nvidia        = [ "amd" "nvidia" ];
    amd-nvidia-prime  = [ "amd" "nvidia-prime" ];
    intel-nvidia      = [ "intel" "nvidia" ];
    intel-nvidia-prime= [ "intel" "nvidia-prime" ];
  };
  shell           = enum "shell"          [ "bash" "zsh" "fish" ];

in {
  inherit
    editor
    version
    platform
    arch
    window-manager
    display-manager
    drive-group
    shell;
}

