# @path: ~/projects/configs/nix-config/home/core/base/portal.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::base::portal
# @directory: https://nix-community.github.io/home-manager/options.xhtml#opt-xdg.portal.enable
#
# User-level XDG portal configuration (standalone HM only).
# On NixOS, portal is managed by nixos/core/base/portal.nix via system config.
# xdg.portal.enable is gated on !shared.isNixOS to avoid double-configuration.
#
# Portal strategy is data-driven from shared.window-manager enum:
#   hyprland → [ "hyprland" "gtk" ]  (xdg-desktop-portal-hyprland + gtk)
#   niri     → [ "wlr" "gtk" ]       (xdg-desktop-portal-wlr + gtk)
#   gnome    → [ "gtk" ]             (xdg-desktop-portal-gtk)


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  xdg.portal = {
    enable = !shared.isNixOS;
    xdgOpenUsePortal = true;

    config = {
      common.default = [ "gtk" ];
      ${shared.window-manager.tag}.default = shared.window-manager.value.portal.value.default;
    };

    # extraPortals installs the portal packages — no need to duplicate in home.packages
    extraPortals = shared.window-manager.value.portal.value.extraPortals pkgs;
  };
}
