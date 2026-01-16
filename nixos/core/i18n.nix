# @path: ~/projects/configs/nix-config/nixos/core/i18n.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::i18n


{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  # https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  # Set TimeZone
  time.hardwareClockInLocalTime = true;
  time.timeZone = "Asia/Shanghai";
  # services.automatic-timezoned.enable = true; # based on IP location

  # Set I18n
  i18n = {
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "zh_CN.UTF-8";
      LC_IDENTIFICATION = "zh_CN.UTF-8";
      LC_MEASUREMENT = "zh_CN.UTF-8";
      LC_MONETARY = "zh_CN.UTF-8";
      LC_NAME = "zh_CN.UTF-8";
      LC_NUMERIC = "zh_CN.UTF-8";
      LC_PAPER = "zh_CN.UTF-8";
      LC_TELEPHONE = "zh_CN.UTF-8";
      LC_TIME = "zh_CN.UTF-8";
    };
    # (move -> home) inputMethod
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [
        fcitx5-rime
        fcitx5-gtk
        qt6Packages.fcitx5-chinese-addons
        qt6Packages.fcitx5-configtool      # config GUI
      ];
    };
  };

  # variables
  environment.variables = {
    GIK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
  };

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts-color-emoji
    # chinese
    noto-fonts-cjk-sans
  ];

  # Configure keymap in X11
  services.xserver.xkb.layout = "us,cn";
  # services.xserver.xkb.options = "caps:escape";  # Caps → Esc

  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

}

