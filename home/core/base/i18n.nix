# @path: ~/projects/configs/nix-config/home/core/sys/i18n.nix
# @author: redskaber
# @datetime: 2026-03-07
# @description: home-manager::core::i18n
# @reference: https://nix-community.github.io/home-manager/options.xhtml#i18n.inputMethod

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  i18n.inputMethod = {
    enable = !shared.isNixOS;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;             # Wayland 支持
      ignoreUserConfig = false;
      addons = with shared.upkgs; [
        fcitx5-rime                       # Rhyme 输入引擎（支持中日韩）
        fcitx5-gtk                        # GTK 应用支持
        qt6Packages.fcitx5-qt             # QT 应用支持
        qt6Packages.fcitx5-chinese-addons # 中文扩展
        qt6Packages.fcitx5-configtool     # 图形化配置工具
        fcitx5-nord                       # Nord 主题
      ];
    };
  };

  # Variables
  home.sessionVariables = {
    LANG = shared.i18n.defaultLocale;
    LC_ADDRESS        = shared.i18n.extraLocalSetting;
    LC_IDENTIFICATION = shared.i18n.extraLocalSetting;
    LC_MEASUREMENT    = shared.i18n.extraLocalSetting;
    LC_MONETARY       = shared.i18n.extraLocalSetting;
    LC_NAME           = shared.i18n.extraLocalSetting;
    LC_NUMERIC        = shared.i18n.extraLocalSetting;
    LC_PAPER          = shared.i18n.extraLocalSetting;
    LC_TELEPHONE      = shared.i18n.extraLocalSetting;
    LC_TIME           = shared.i18n.extraLocalSetting;
  };

  # Used user config:
  xdg.configFile."fcitx5" = {
    source = inputs.fcitx5-config; # abs path
    recursive = true; # rec-link
    force = true;
  };

}


