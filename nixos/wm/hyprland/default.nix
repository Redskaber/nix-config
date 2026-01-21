# @path: ~/projects/configs/nix-config/nixos/wm/hyprland/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::wm::hyprland


{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.hyprland.enable = true;
  services.displayManager.gdm.enable = true;


  # For Electron apps to use wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  # Used Hyprland cursor
  environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";
  # For Hyprland QT Support
  environment.sessionVariables.QML_IMPORT_PATH = "${pkgs.hyprland-qt-support}/lib/qt-6/qml";
  # GTK app Wayland
  environment.sessionVariables.GDK_BACKEND = "wayland";
  # Electron app to wayland
  environment.sessionVariables.ELECTRON_OZONE_PLATFORM_HINT = "auto";

}


