# @path: ~/projects/configs/nix-config/platform/nixos/core/base/i18n.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::core::base::i18n
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
  # Set TimeZone
  time.hardwareClockInLocalTime = false;
  time.timeZone = shared.time.timeZone;
  services.automatic-timezoned.enable = shared.time.used-ip-timeZone; # based on IP location

  # Set I18n
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

    # FIXME(fix@2026-10-08): 中文输入法 (not available) 根因与修复
    # 根因: `i18n.inputMethod` 模块用 `pkgs.qt6Packages.fcitx5-with-addons`
    #   组装 daemon，core 停留在 stable (fcitx5 5.1.19)；而 addons 若取
    #   `shared.upkgs` (nixpkgs-unstable)，则 chinese-addons 5.1.14 的
    #   addon 元数据声明硬依赖 `core:5.1.22`，fcitx5 启动时依赖检查失败
    #   (checkDependencies returns 3)，pinyin/punctuation/pinyinhelper/
    #   cloudpinyin/chinese-addons 全家拒绝加载 → configtool 中中文输入法
    #   显示 (not available)，无法输入中文。
    # 修复: addons 与 daemon 同源 (pkgs, stable 26.05)，版本约束
    #   chinese-addons 5.1.12 仅要求 core>=5.1.13，与 core 5.1.19 兼容。
    #   运行时验证: stable core + stable addons → pinyin 正常加载；
    #   stable core + unstable addons → 全部中文引擎拒载。
    # 原则: fcitx5 core 与所有 addon 必须来自同一份 nixpkgs 实例，
    #   切勿 stable/unstable 混用 (addon 的 ABI/元数据版本约束不跨源保证)。
    #
    # T2.6 (双源治理): 该原则已固化为 eval 期守卫 —
    #   1. addon 列表改为作用域参数化策略 (portal.extraPortals 模式)，
    #      模块内不再出现可翻转的 `with` 作用域；
    #   2. 策略的作用域经 `shared.fn.sameSource` 指纹校验：策略声明的
    #      nixpkgs 源 (i18n.nixpkgs-source, 默认 stable) 与 daemon 实际
    #      所在的模块系统 pkgs 指纹一致才放行，否则 eval 立即报错并
    #      引用 995d8c9。混源组合从「登录界面才死」变为「求值期即死」。
    inputMethod =
      let
        # daemon 所在作用域: i18n.inputMethod 从模块系统 pkgs 组装 daemon。
        daemonScope = pkgs;
        # T4.0: 策略声明的源在 runtime 层解析一次 (shared.i18nScope) —
        # 本模块只保留 sameSource 指纹守卫，不再持有第二份选择分支
        # （原先 home/nixos 两侧各抄一遍同一个 if-else）。
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

  # variables
  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1"; # wayland sup
  };

  # Fonts
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
