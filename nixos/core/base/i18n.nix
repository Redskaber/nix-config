# @path: ~/projects/configs/nix-config/nixos/core/base/i18n.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::base::i18n


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  # https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  # Set TimeZone
  time.hardwareClockInLocalTime = false;
  time.timeZone = shared.time.timeZone;
  services.automatic-timezoned.enable = shared.time.used-ip-timeZone; # based on IP location

  # Set I18n
  i18n = {
    defaultLocale       = shared.i18n.defaultLocale;
    extraLocales        = shared.i18n.extraLocales;
    extraLocaleSettings = {
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

    inputMethod = {
      type = "fcitx5";
      enable = true;
      enableGtk2 = true;
      enableGtk3 = true;
      fcitx5 = {
        waylandFrontend = true;             # suppress warning
        addons = with pkgs; [
          fcitx5-rime                       # Traditional chinese
          fcitx5-gtk
          qt6Packages.fcitx5-chinese-addons # Chinese
          qt6Packages.fcitx5-configtool     # Config GUI
          fcitx5-nord                       # Color-theme
        ];
      };
    };

  };

  # variables
  environment.sessionVariables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE  = "fcitx";
    QT_IM_MODULES = "wayland;fcitx;ibus"; # Qt6.7+
    XMODIFIERS    = "@im=fcitx";          # xwayland
    SDL_IM_MODULE = "fcitx";              # sdl
    MOZ_ENABLE_WAYLAND = "1";             # wayland sup
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
  # services.xserver.xkb.options = "caps:escape";

  services.xserver.desktopManager.runXdgAutostartIfNone = true;

  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

}


