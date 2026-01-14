# @path: ~/projects/configs/nix-config/src/wm/hyprland/monitor.nix
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
  monitors = [ "eDP-1, preferred, auto, 1" ];  # 笔记本
  # monitors = [
  #   "DP-1, 2560x1440@144, 0x0, 1"
  #   "HDMI-A-1, 1920x1080@60, 2560x0, 2"
  # ];  # 桌面双屏
in
{
  wayland.windowManager.hyprland.settings.monitor = monitors;

  # 快捷键：Win + P 打开显示器配置工具
  wayland.windowManager.hyprland.settings.bind = [
    "SUPER, P, exec, ${pkgs.nwg-displays}/bin/nwg-displays"
  ];

  home.packages = with pkgs; [ nwg-displays ];
}


