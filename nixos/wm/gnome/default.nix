# @path: ~/projects/configs/nix-config/nixos/wm/gnome/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::wm::gnome


{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  # Enable Gnome
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
}


