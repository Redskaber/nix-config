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
      waylandFrontend = true;             # Wayland support
      ignoreUserConfig = false;
      addons = with shared.upkgs; [
        fcitx5-rime                       # Rhyme input engine (CJK support)
        fcitx5-gtk                        # GTK application support
        qt6Packages.fcitx5-qt             # QT application support
        qt6Packages.fcitx5-chinese-addons # Chinese extensions
        qt6Packages.fcitx5-configtool     # GUI config tool
        fcitx5-nord                       # Nord theme
      ];
    };
  };

  # Variables
  home.sessionVariables = {
    LANG          = shared.i18n.defaultLocale;
    LC_ADDRESS    = shared.i18n.extraLocalSetting;
    LC_IDENTIFICATION = shared.i18n.extraLocalSetting;
    LC_MEASUREMENT    = shared.i18n.extraLocalSetting;
    LC_MONETARY   = shared.i18n.extraLocalSetting;
    LC_NAME       = shared.i18n.extraLocalSetting;
    LC_NUMERIC    = shared.i18n.extraLocalSetting;
    LC_PAPER      = shared.i18n.extraLocalSetting;
    LC_TELEPHONE  = shared.i18n.extraLocalSetting;
    LC_TIME       = shared.i18n.extraLocalSetting;
  };

  # Used user config:
  xdg.configFile."fcitx5" = {
    source = inputs.fcitx5-config;  # abs path
    recursive = true;               # rec-link
    force = true;
  };

}


