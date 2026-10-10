# @path: ~/projects/configs/nix-config/platform/nixos/wm/gnome/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::wm::gnome

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  # Enable Gnome
  services.xserver.enable = true;
  # services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
}
