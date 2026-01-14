# @path: ~/projects/configs/nix-config/nixos/core/wayland.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=hyprland


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  programs.hyprland = {
    enable = true;
  };

  # base(wayland)
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config = {
      common.default = [ "gtk" ];
      hyprland.default = [ "hyprland" "gtk" ];
    };

    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
  };
}


