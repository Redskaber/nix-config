# @path: ~/projects/configs/nix-config/src/wm/hyprland/exec-once.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  browser = "${inputs.zen-browser.packages.${pkgs.stdenv.system}.beta}/bin/zen-beta";
in {
  wayland.windowManager.hyprland.settings.exec-once = [
    # 环境变量同步
    "dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"

    # 后台服务
    "nm-applet &"
    "poweralertd &"
    "wl-clip-persist --clipboard both &"
    "wl-paste --watch cliphist store &"
    "waybar &"
    "swaync &"
    "udiskie --automount --notify --smart-tray &"

    # UI 初始化
    "hyprctl setcursor Bibata-Modern-Ice 24"

    # 初始壁纸
    "init-wallpaper &"

    # 初始应用（使用 hyprctl dispatch exec 控制工作区）
    "hyprctl dispatch exec '[workspace 1 silent] ${browser}'"
    "hyprctl dispatch exec '[workspace 2 silent] ${pkgs.ghostty}/bin/ghostty'"
  ];
}


