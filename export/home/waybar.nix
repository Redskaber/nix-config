# @path: ~/projects/configs/nix-config/export/home/waybar.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: export::home::waybar — reusable themable status-bar module
#
# Standalone, options-first distillation of home/wm/*/theme/waybar.nix:
# link a waybar config stack into ~/.config/waybar and (optionally)
# install a wallust colors file on top of it — theme refresh without
# touching the config stack. The package comes from the module's own pkgs
# by default (single-source contract), instead of a hardcoded unstable
# package set.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.redskaber.waybar;
in
{
  options.redskaber.waybar = {
    enable = lib.mkEnableOption "waybar with a themable config stack";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.waybar;
      defaultText = "pkgs.waybar";
      description = "waybar package (defaults to the module's own package set).";
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      description = "waybar configuration directory, linked to ~/.config/waybar.";
    };

    wallustColors = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Optional wallust colors file installed as
        ~/.config/waybar/colors-waybar.css after every activation —
        recolours the bar without editing the config stack.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."waybar" = {
      source = cfg.configDir;
      recursive = true;
      force = true;
    };

    home.activation.waybarWallust = lib.mkIf (cfg.wallustColors != null) (
      lib.hm.dag.entryAfter [
        "writeBoundary"
      ] ''install -Dm0644 "${cfg.wallustColors}" "$HOME/.config/waybar/colors-waybar.css"''
    );
  };
}
