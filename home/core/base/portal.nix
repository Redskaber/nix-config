# @path: ~/projects/configs/nix-config/home/core/base/portal.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::base::portal
# @directory: https://nix-community.github.io/home-manager/options.xhtml#opt-xdg.portal.enable
#
# User-level XDG portal configuration (standalone HM only).
# On NixOS, portal is managed by nixos/core/base/portal.nix via system config.
# xdg.portal.enable is gated on the resolved capability facts (T4.0):
# !caps.nixos-system (system layer owns it) && desktop-session (a real
# desktop session exists to mediate) — no predicate calls, no tag strings.
#
# Portal strategy is data-driven from shared.window-manager enum:
#   hyprland → [ "hyprland" "gtk" ]  (xdg-desktop-portal-hyprland + gtk)
#   niri     → [ "wlr" "gtk" ]       (xdg-desktop-portal-wlr + gtk)
#   gnome    → [ "gtk" ]             (xdg-desktop-portal-gtk)
#   none     → portal disabled       (T3.1/T3.2: headless hosts — enabling
#             a portal with zero backends trips HM's own assertion; the
#             none strategy means "no windowing stack to mediate at all")

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  xdg.portal = {
    # Gate on BOTH resolved facts (T3.1 fix, T4.0 capability-routed):
    # the NixOS system layer manages portals there, and a headless
    # strategy means no desktop session — nothing to mediate.
    enable = !shared.caps.nixos-system && shared.window-manager.value.desktop-session;
    xdgOpenUsePortal = shared.window-manager.value.desktop-session;

    config = {
      common.default = [ "gtk" ];
      ${shared.window-manager.tag}.default = shared.window-manager.value.portal.value.default;
    };

    # extraPortals installs the portal packages — no need to duplicate in home.packages
    extraPortals = shared.window-manager.value.portal.value.extraPortals pkgs;
  };
}
