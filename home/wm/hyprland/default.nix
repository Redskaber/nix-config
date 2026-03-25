# @path: ~/projects/configs/nix-config/home/wm/hyprland/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml
# @depends-and-description:
# - hypridle        : Hyprland's idle daemon
# - hyprlock        : Hyprland's GPU-accelerated screen locking utility
# - hyprpolkitagent : Polkit authentication agent written in QT/QML
# - pyprland        : Hyperland plugin system (python)
# - uwsm    (option): Universal wayland session manager
# - hyprlang(option): Official implementation library for the hypr config language
# - hyprshot(option): Utility to easily take screenshots in Hyprland using your mouse
# - hyprcursor(optimite): Hyprland cursor format, library and utilities
# - nwg-displays(option): Output management utility for Sway and Hyprland
# - nwg-look        : GTK settings editor, designed to work properly in wlroots-based Wayland environment
# - waypaper(option): GUI wallpaper setter for Wayland-based window managers (mp4 wallpaper sup)
# - swww            : Efficient animated wallpaper daemon for wayland, controlled at runtime
# - waybar          : Highly customizable Wayland bar for Sway and Wlroots based compositors
# - hyprland-qt-support: Qt6 QML provider for hypr* apps
# - rofi            : Window switcher, run dialog and dmenu replacement
# - grim            : Grab images from a Wayland compositor
# - slurp           : Select a region in a Wayland compositor
# - swappy          : Wayland native snapshot editing tool, inspired by Snappy on macOS
# - swaynotificationcenter: Simple notification daemon with a GUI built for Sway
# - wallust         : Better pywal, Terminal wallpaper management tool written in Rust
# - wlogout         : Wayland based logout menu
# - quickshell(option): Flexbile QtQuick based desktop shell toolkit
# - ags     (option): Scaffolding CLI for Astal widget system
# - grimblast(option): Helper for screenshots within Hyprland, based on grimshot
# - hyprpicker(option): Wlroots-compatible Wayland color picker that does not suck
# - wf-recorder(option): Utility program for screen recording of wlroots-based compositors
# - yad   (KeyHints): GUI dialog tool for shell scripts
# - cliphist        : Wayland clipboard manager (copy)
# - wl-clip-persist : Keep Wayland clipboard even after programs close
# - swayosd (option): GTK based on screen display for keyboard shortcuts


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  # hyprland configs
  imports = [
    ./theme
  ];

  # nixos manager
  # programs.hyprland.enable = true;
  home.packages = with pkgs; [
    pyprland
    hyprlang
    hypridle
    hyprlock
    hyprcursor
    hyprpolkitagent
    hyprland-qt-support
    nwg-displays
    nwg-look
    waypaper
    swww
    yad
    hyprpicker
    wf-recorder
  ];

  # hyprland through system enable
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    xwayland.enable = true;
    systemd = {
      enable = true;
      enableXdgAutostart = true;    # auto-enable: ~/.config/autostart/
    };
  };

  # Used Hyprland config
  xdg.configFile."hypr" = {
    source = inputs.hypr-config;    # abs path
    recursive = true;               # rec-link
    force = true;
  };

  # Env Variables
  home.sessionVariables = {
    GDK_BACKEND = "wayland,x11";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    XDG_CURRENT_DESKTOP = "Hyprland";
  };


}

