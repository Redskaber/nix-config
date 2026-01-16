# @path: ~/projects/configs/nix-config/nixos/core/portal.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=hyprland
# @description: nixos::core::portal


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  # base(wayland)
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    xdgOpenUsePortal = true;

    config = {
      common.default = [ "gtk" ];
      hyprland.default = [ "hyprland" "gtk" "wlr" ];
    };

    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];

  };

}


