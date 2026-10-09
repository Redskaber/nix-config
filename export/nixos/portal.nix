# @path: ~/projects/configs/nix-config/export/nixos/portal.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: export::nixos::portal — reusable XDG portal module
#
# Standalone, options-first version of nixos/core/base/portal.nix — no
# `shared` dependency: any external flake can import it via
# `inputs.nix-config.nixosModules.portal`. The backend strategy is
# scope-parameterized (the caller injects the module's own pkgs), so the
# portal backends resolve from the same package set as the rest of the
# system — single-source by construction.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.redskaber.portal;

  # Portal stacks per backend (scope-parameterized, single-source contract).
  extraPortals =
    backend: scope:
    with scope;
    {
      gtk = [ xdg-desktop-portal-gtk ];
      gnome = [ xdg-desktop-portal-gtk ];
      niri = [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
      ];
      # hyprland's own portal ships with the Hyprland ecosystem; the gtk
      # backend keeps this module standalone (hyprland users can append
      # xdg-desktop-portal-hyprland via extraPortals).
      hyprland = [ xdg-desktop-portal-gtk ];
    }
    .${backend};

  # Default interface selection per backend.
  defaults = {
    gtk = [ "gtk" ];
    gnome = [ "gtk" ];
    niri = [
      "wlr"
      "gtk"
    ];
    hyprland = [
      "hyprland"
      "gtk"
    ];
  };
in
{
  options.redskaber.portal = {
    enable = lib.mkEnableOption "XDG desktop portal (Wayland)";

    backend = lib.mkOption {
      type = lib.types.enum [
        "gtk"
        "gnome"
        "niri"
        "hyprland"
      ];
      default = "gtk";
      description = "Which portal stack to wire (interface defaults + extra backends).";
    };

    xdgOpenUsePortal = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Make xdg-open hand off to the portal.";
    };

    extraPortals = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional portal backends appended to the backend preset.";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.portal = {
      enable = true;
      wlr.enable = cfg.backend == "niri";
      inherit (cfg) xdgOpenUsePortal;
      config.common.default = defaults.${cfg.backend};
      extraPortals = extraPortals cfg.backend pkgs ++ cfg.extraPortals;
    };
  };
}
