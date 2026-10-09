# @path: ~/projects/configs/nix-config/export/home/fcitx5.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: export::home::fcitx5 — reusable HM input method module
#
# Standalone Home Manager twin of export/nixos/fcitx5.nix (the shape of
# home/core/base/i18n.nix): for non-NixOS platforms where HM assembles
# the fcitx5 daemon itself. Same scope-parameterized addon preset — the
# daemon scope is HM's own pkgs, so addons resolve single-sourced.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.redskaber.fcitx5;

  # zh-CN addon preset, scope-parameterized (single-source contract).
  preset =
    scope: with scope; [
      fcitx5-rime
      fcitx5-gtk
      qt6Packages.fcitx5-qt
      qt6Packages.fcitx5-chinese-addons
      qt6Packages.fcitx5-configtool
      fcitx5-nord
    ];
in
{
  options.redskaber.fcitx5 = {
    enable = lib.mkEnableOption "fcitx5 input method with a zh-CN addon preset (Home Manager)";

    waylandFrontend = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use the Wayland input-method protocol.";
    };

    usePreset = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the zh-CN addon preset (see export/nixos/fcitx5.nix).";
    };

    extraAddons = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional fcitx5 addons appended to the preset (same nixpkgs instance as the daemon).";
    };

    settings = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional fcitx5 configuration directory to link into ~/.config/fcitx5.";
    };
  };

  config = lib.mkIf cfg.enable {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        inherit (cfg) waylandFrontend;
        addons = cfg.extraAddons ++ lib.optionals cfg.usePreset (preset pkgs);
      };
    };

    xdg.configFile."fcitx5" = lib.mkIf (cfg.settings != null) {
      source = cfg.settings;
      recursive = true;
      force = true;
    };
  };
}
