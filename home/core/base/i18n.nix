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
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-rime                       # Rime 输入引擎（支持中日韩）
        fcitx5-gtk                        # GTK 应用支持
        qt6Packages.fcitx5-chinese-addons # 中文扩展
        qt6Packages.fcitx5-configtool     # 图形化配置工具
        fcitx5-nord                       # Nord 主题
      ];
      settings.globalOptions = {
        Behavior = {
          ActiveByDefault = true;
        };
      };
      settings.inputMethod = {
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";       # 默认键盘布局
          DefaultIM = "pinyin";          # 默认输入引擎
        };
        "Groups/0/Items/0" = { Name = "keyboard-us"; };
        "Groups/0/Items/1" = { Name = "pinyin"; };
        "Groups/0/Items/2" = { Name = "rime"; };
        GroupOrder."0" = "Default";
      };
      settings.addons.rime = {
        globalSection = {
          CloudInputEnabled = "True";
          SimplifiedMode = "0";
        };
      };
      quickPhrase = {
        smile = "（・∀・）";
        angry = "(╬ Ò﹏Ó)";
        happy = "(≧▽≦)";
      };
    };
  };

  # Variables
  home.sessionVariables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    QT_IM_MODULES = "wayland;fcitx;ibus";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
    LANG = "en_US.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
  };


}


