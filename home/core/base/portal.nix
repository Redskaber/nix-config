# @path: ~/projects/configs/nix-config/home/core/base/portal.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::base::portal
# @directory: https://nix-community.github.io/home-manager/options.xhtml#opt-xdg.portal.enable
#
# User-level XDG portal configuration (standalone HM only).
# On NixOS, portal is managed by platform/nixos/system/core/base/portal.nix via system config.
# xdg.portal.enable is gated on the resolved capability facts:
# !caps.nixos-system (system layer owns it) && desktop-session — no
# predicate calls, no tag strings.
#
# Portal strategy is data-driven from the shared.window-manager enum
# (each row picks its backend set). none → portal disabled: enabling
# a portal with zero backends trips HM's own assertion — headless hosts
# have no windowing stack to mediate at all.

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
    # Gate on BOTH resolved facts: the NixOS system layer manages
    # portals there, and headless means no desktop session to mediate.
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
