# @path: ~/projects/configs/nix-config/export/nixos/fcitx5.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: export::nixos::fcitx5 — reusable Chinese input method module
#
# Standalone, options-first version of the inputMethod half of
# nixos/core/base/i18n.nix. Scope-parameterized addon preset (the
# portal.extraPortals pattern): the preset resolves from the module's
# own pkgs — the same set i18n.inputMethod assembles the daemon from —
# so the stable/unstable mixing that caused the 995d8c9 incident is
# structurally impossible here (see docs/modules/interface-standards.md).

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
      fcitx5-rime # Rime engine (CJK)
      fcitx5-gtk # GTK application support
      qt6Packages.fcitx5-qt # QT application support
      qt6Packages.fcitx5-chinese-addons # Chinese extensions
      qt6Packages.fcitx5-configtool # GUI config tool
      fcitx5-nord # theme
      catppuccin-fcitx5 # theme
    ];
in
{
  options.redskaber.fcitx5 = {
    enable = lib.mkEnableOption "fcitx5 input method with a zh-CN addon preset";

    waylandFrontend = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use the Wayland input-method protocol (recommended under Hyprland/Niri IMv2).";
    };

    usePreset = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the zh-CN addon preset (rime, chinese-addons, gtk/qt frontends, configtool, themes).";
    };

    extraAddons = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Additional fcitx5 addons appended to the preset. Draw them from
        the same package set as the daemon (the module's own pkgs) —
        fcitx5 addons declare core-version constraints that are not
        guaranteed across nixpkgs instances.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    i18n.inputMethod = {
      type = "fcitx5";
      enable = true;
      fcitx5 = {
        inherit (cfg) waylandFrontend;
        addons = cfg.extraAddons ++ lib.optionals cfg.usePreset (preset pkgs);
      };
    };
  };
}
