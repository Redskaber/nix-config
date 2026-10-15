# @path: ~/projects/configs/nix-config/platform/nixos/system/core/base/i18n.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::base::i18n
# fcitx5:
#   1.terminal run fcitx5
#   2.terminal run fcitx5-configtool
# to set your input method

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{

  # https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  time.hardwareClockInLocalTime = false;
  time.timeZone = shared.time.timeZone;
  services.automatic-timezoned.enable = shared.time.used-ip-timeZone; # based on IP location

  i18n = {
    defaultLocale = shared.i18n.defaultLocale;
    extraLocales = shared.i18n.extraLocales;
    extraLocaleSettings = {
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

    # 原则 (FIXME 已修, 2026-10-08): fcitx5 core 与所有 addon 必须来自
    # 同一份 nixpkgs 实例 — 混源 (stable core + unstable addons) 会让
    # addon 元数据的 core 版本约束失败 (checkDependencies returns 3)，
    # 中文引擎全部拒载 (configtool 显示 not available)。该原则已固化为
    # eval 期守卫 (双源治理): addon 列表作用域参数化 +
    # shared.fn.sameSource 指纹校验 — 策略声明的 nixpkgs 源
    # (i18n.nixpkgs-source) 与 daemon 实际所在的模块系统 pkgs 指纹
    # 一致才放行，否则 eval 立即报错。混源组合从「登录界面才死」
    # 变为「求值期即死」。
    inputMethod =
      let
        # daemon 所在作用域: i18n.inputMethod 从模块系统 pkgs 组装 daemon。
        daemonScope = pkgs;
        # 策略声明的源在 runtime 层解析一次 (shared.i18nScope) —
        # 本模块只保留 sameSource 指纹守卫，不持有第二份选择分支。
        addonScope =
          shared.fn.sameSource "i18n.inputMethod.fcitx5 (declared: ${shared.i18n.nixpkgs-source})" daemonScope
            shared.i18nScope;
        # 作用域参数化的 addon 策略 (同 export/nixos/fcitx5.nix 的 preset)。
        addonSet =
          scope: with scope; [
            fcitx5-rime # Rhyme 输入引擎（支持中日韩）
            fcitx5-gtk # GTK 应用支持
            qt6Packages.fcitx5-qt # QT 应用支持
            qt6Packages.fcitx5-chinese-addons # 中文扩展
            qt6Packages.fcitx5-configtool
            # 图形化配置工具
            # theme
            fcitx5-nord
            catppuccin-fcitx5
          ];
      in
      {
        type = "fcitx5";
        enable = true;
        enableGtk2 = true;
        enableGtk3 = true;
        fcitx5 = {
          waylandFrontend = true; # suppress warning
          ignoreUserConfig = false;
          addons = addonSet addonScope;
          # quickPhrase = {};
          # quickPhraseFiles = {};
        };
      };

  };

  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1"; # wayland sup
  };

  fonts.fontconfig.enable = true;
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts-color-emoji
    # chinese sup
    noto-fonts-cjk-sans
  ];

  # Configure keymap in X11
  services.xserver.xkb.layout = "us,cn";
  # services.xserver.xkb.extraLayouts = {};
  # services.xserver.xkb.variant = "";
  # services.xserver.xkb.options = "caps:escape";

  services.xserver.desktopManager.runXdgAutostartIfNone = true;

  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

}
