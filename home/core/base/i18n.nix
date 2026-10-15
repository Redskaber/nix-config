# @path: ~/projects/configs/nix-config/home/core/base/i18n.nix
# @author: redskaber
# @datetime: 2026-03-07
# @description: home-manager::core::i18n
# @reference: https://nix-community.github.io/home-manager/options.xhtml#i18n.inputMethod

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  # fcitx5 daemon 由 HM 的 pkgs 组装，addons 必须与之同源——混源
  # (upkgs) 会因 core/addon 版本依赖不满足导致中文输入法不可用。
  # eval 期守卫：addon 作用域经 shared.fn.sameSource 与策略声明源
  # (i18n.nixpkgs-source) 和 daemon 实际作用域双重指纹校验。
  i18n.inputMethod =
    let
      daemonScope = pkgs;
      # The declared source scope is resolved ONCE in the runtime layer
      # (shared.i18nScope) — only the sameSource fingerprint guard here.
      addonScope =
        shared.fn.sameSource "home i18n.inputMethod.fcitx5 (declared: ${shared.i18n.nixpkgs-source})"
          daemonScope
          shared.i18nScope;
      addonSet =
        scope: with scope; [
          fcitx5-rime # Rhyme input engine (CJK support)
          fcitx5-gtk # GTK application support
          qt6Packages.fcitx5-qt # QT application support
          qt6Packages.fcitx5-chinese-addons # Chinese extensions
          qt6Packages.fcitx5-configtool # GUI config tool
          fcitx5-nord # Nord theme
        ];
    in
    {
      # NixOS layer owns the input method there; darwin owns it via OS
      # input sources (fcitx5 is not a darwin package) — standalone Linux
      # (incl. wsl) is the only family this module serves, composed from
      # resolved capability facts, not a re-derived predicate chain.
      enable = shared.caps.linux-family && !shared.caps.nixos-system;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true; # Wayland support
        ignoreUserConfig = false;
        addons = addonSet addonScope;
      };
    };

  home.sessionVariables = {
    LANG = shared.i18n.defaultLocale;
    LC_ADDRESS = shared.i18n.extraLocalSetting;
    LC_IDENTIFICATION = shared.i18n.extraLocalSetting;
    LC_MEASUREMENT = shared.i18n.extraLocalSetting;
    LC_MONETARY = shared.i18n.extraLocalSetting;
    LC_NAME = shared.i18n.extraLocalSetting;
    LC_NUMERIC = shared.i18n.extraLocalSetting;
    LC_PAPER = shared.i18n.extraLocalSetting;
    LC_TELEPHONE = shared.i18n.extraLocalSetting;
    LC_TIME = shared.i18n.extraLocalSetting;
  };

  xdg.configFile."fcitx5" = {
    source = inputs.fcitx5-config; # abs path
    recursive = true; # rec-link
    force = true;
  };

}
