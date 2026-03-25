# @path: ~/projects/configs/nix-config/nixos/wm/hyprland/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::wm::hyprland


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./plugins     # plugins
  ];

  environment.systemPackages = with pkgs; [
    openssl       # rain-border dep
    libqalculate  # clac allocate dep
    libnotify     # notify dep
    bc            # wallpaper select dep
    mpvpaper      # mp4 wallpaper dep
  ];

  programs.hyprland = {
    enable = true;
    # package = pkgs.hyprland;
    # portalPackage = pkgs.xdg-desktop-portal-hyprland;
    package = inputs.hyprland.packages.${shared.arch.tag}.hyprland;
    portalPackage = inputs.hyprland.packages.${shared.arch.tag}.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };
  environment.sessionVariables = {
    # For Electron apps to use wayland
    NIXOS_OZONE_WL = "1";
    # Used Hyprland cursor
    WLR_NO_HARDWARE_CURSORS = "1";
    # For Hyprland QT Support (Optional)
    QML_IMPORT_PATH = "${pkgs.hyprland-qt-support}/lib/qt-6/qml";
    # GTK app Wayland
    GDK_BACKEND = "wayland";
    # Electron app to wayland
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };


}


