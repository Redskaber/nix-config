# @path: ~/projects/configs/nix-config/export/home/yazi.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: export::home::yazi — reusable file-manager module
#
# Standalone, options-first distillation of
# home/core/exp/sys/base/yazi/: the plugin preset (lazygit, full-border,
# git, smart-enter), shell integrations and the theme hand-off are all
# options now — callers keep their own settings/keymap/theme and append
# plugins from the module's package set (single-source contract).

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.redskaber.yazi;

  # Plugin preset, scope-parameterized (single-source contract).
  presetPlugins =
    scope: with scope.yaziPlugins; {
      inherit
        lazygit
        full-border
        git
        smart-enter
        ;
    };

  presetInitLua = ''
    require("full-border"):setup()
    require("git"):setup()
    require("smart-enter"):setup {
      open_multi = true,
    }
  '';
in
{
  options.redskaber.yazi = {
    enable = lib.mkEnableOption "yazi file manager with the plugin preset";

    shellWrapperName = lib.mkOption {
      type = lib.types.str;
      default = "yy";
      description = "Wrapper command name for the shell integration.";
    };

    usePreset = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the plugin preset (lazygit, full-border, git, smart-enter) and its initLua.";
    };

    extraPlugins = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = { };
      description = "Extra plugins merged over the preset, keyed by name (e.g. from pkgs.yaziPlugins).";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "yazi settings (programs.yazi.settings).";
    };

    keymap = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "yazi keymap (programs.yazi.keymap).";
    };

    theme = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional theme.toml linked to ~/.config/yazi/theme.toml.";
    };

    zshIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Shell integration for zsh.";
    };

    fishIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Shell integration for fish.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      shellWrapperName = cfg.shellWrapperName;
      enableZshIntegration = cfg.zshIntegration;
      enableFishIntegration = cfg.fishIntegration;
      settings = cfg.settings;
      keymap = cfg.keymap;
      plugins = (lib.optionalAttrs cfg.usePreset (presetPlugins pkgs)) // cfg.extraPlugins;
      initLua = lib.optionalString cfg.usePreset presetInitLua;
    };

    xdg.configFile."yazi/theme.toml" = lib.mkIf (cfg.theme != null) {
      source = cfg.theme;
    };
  };
}
