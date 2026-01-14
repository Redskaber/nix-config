# @path: ~/projects/configs/nix-config/src/wm/hyprland/bind.nix
# @author: redskaber
# @datetime: 2025-12-12
# @directory: https://nix-community.github.io/home-manager/options.xhtml
# @depends:
# - ghostty
# - rofi
# - nemo
# - zen-browser


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.system;
  mod = "SUPER";
  apps = {
    term = "${pkgs.ghostty}/bin/ghostty";
    fileManager = "${pkgs.nemo}/bin/nemo";
    browser = "${inputs.zen-browser.packages.${system}.beta}/bin/zen-beta";
    rofi = "${pkgs.rofi}/bin/rofi";
    # waybarToggle = "toggle-waybar";
    # screenshot = "screenshot";
    lock = "${pkgs.swaylock}/bin/swaylock";
    hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
    # powerMenu = "power-menu";
    # wallpaperPicker = "wallpaper-picker";
    waypaper = "${pkgs.waypaper}/bin/waypaper";
    woomer = "${pkgs.woomer}/bin/woomer";
    missioncenter = "${pkgs.mission-center}/bin/missioncenter";
    soundwire = "SoundWireServer";
    cliphist = "${pkgs.cliphist}/bin/cliphist";
    wlCopy = "${pkgs.wl-clipboard}/bin/wl-copy";
  };
in
{
  wayland.windowManager.hyprland.settings = {
    # === 全局行为设置 ===
    # scroll_event_delay = 100;
    # movefocus_cycles_fullscreen = true;

    # === 修饰键 ===
    "$mod" = mod;

    # === 主要快捷键绑定 ===
    bind = [
      # 应用启动
      "${mod}, ENTER, exec, ${pkgs.kitty}/bin/kitty"
      "${mod}, Return, exec, ${apps.term} --gtk-single-instance=true"
      "ALT, Return, exec, [float; size 1111 700] ${apps.term}"
      "${mod} SHIFT, Return, exec, [fullscreen] ${apps.term}"

      "${mod}, B, exec, [workspace 1 silent] ${apps.browser}"
      "${mod}, E, exec, ${apps.fileManager}"
      "ALT, E, exec, [float; size 1111 700] ${apps.fileManager}"

      "${mod}, D, exec, toggle-rofi ${apps.rofi} -show drun"
      "${mod} SHIFT, D, exec, vesktop --enable-features=UseOzonePlatform --ozone-platform=wayland"

      # 系统控制
      "${mod}, Q, killactive,"
      "${mod} SHIFT, Q, exit,"
      "${mod}, Escape, exec, ${apps.lock}"
      "ALT, Escape, exec, ${apps.hyprlock}"
      # "${mod} SHIFT, Escape, exec, ${apps.powerMenu}"

      # 窗口行为
      "${mod}, F, fullscreen, 0"
      "${mod} SHIFT, F, fullscreen, 1"
      "${mod}, Space, exec, toggle-float"
      "${mod}, P, pseudo,"
      "${mod}, X, togglesplit,"
      "${mod}, T, exec, toggle-oppacity"

      # 工具
      "${mod}, C, exec, ${pkgs.hyprpicker}/bin/hyprpicker -a"
      # "${mod}, W, exec, ${apps.wallpaperPicker}"
      "${mod} SHIFT, W, exec, [float; size 925 615] ${apps.waypaper}"
      "${mod}, N, exec, swaync-client -t -sw"
      "${mod}, equal, exec, ${apps.woomer}"

      # 剪贴板
      "${mod}, V, exec, ${apps.cliphist} list | ${apps.rofi} -dmenu -theme-str 'window {width: 50%;} listview {columns: 1;}' | ${apps.cliphist} decode | ${apps.wlCopy}"

      # 截图
      # ", Print, exec, ${apps.screenshot} --copy"
      # "${mod}, Print, exec, ${apps.screenshot} --save"
      # "${mod} SHIFT, Print, exec, ${apps.screenshot} --swappy"

      # 工作区切换 (1-10)
      "${mod}, 1, workspace, 1"
      "${mod}, 2, workspace, 2"
      "${mod}, 3, workspace, 3"
      "${mod}, 4, workspace, 4"
      "${mod}, 5, workspace, 5"
      "${mod}, 6, workspace, 6"
      "${mod}, 7, workspace, 7"
      "${mod}, 8, workspace, 8"
      "${mod}, 9, workspace, 9"
      "${mod}, 0, workspace, 10"

      # 移动窗口到工作区（静默）
      "${mod} SHIFT, 1, movetoworkspacesilent, 1"
      "${mod} SHIFT, 2, movetoworkspacesilent, 2"
      "${mod} SHIFT, 3, movetoworkspacesilent, 3"
      "${mod} SHIFT, 4, movetoworkspacesilent, 4"
      "${mod} SHIFT, 5, movetoworkspacesilent, 5"
      "${mod} SHIFT, 6, movetoworkspacesilent, 6"
      "${mod} SHIFT, 7, movetoworkspacesilent, 7"
      "${mod} SHIFT, 8, movetoworkspacesilent, 8"
      "${mod} SHIFT, 9, movetoworkspacesilent, 9"
      "${mod} SHIFT, 0, movetoworkspacesilent, 10"
      "${mod} CTRL, c, movetoworkspace, empty"

      # 焦点移动（仅保留 h/j/k/l，避免与方向键冲突）
      "${mod}, h, movefocus, l"
      "${mod}, j, movefocus, d"
      "${mod}, k, movefocus, u"
      "${mod}, l, movefocus, r"

      # 窗口移动
      "${mod} SHIFT, h, movewindow, l"
      "${mod} SHIFT, j, movewindow, d"
      "${mod} SHIFT, k, movewindow, u"
      "${mod} SHIFT, l, movewindow, r"

      # 调整大小
      "${mod} CTRL, h, resizeactive, -80 0"
      "${mod} CTRL, j, resizeactive, 0 80"
      "${mod} CTRL, k, resizeactive, 0 -80"
      "${mod} CTRL, l, resizeactive, 80 0"

      # 微调位置（带 ALT）
      "${mod} ALT, h, moveactive, -80 0"
      "${mod} ALT, j, moveactive, 0 80"
      "${mod} ALT, k, moveactive, 0 -80"
      "${mod} ALT, l, moveactive, 80 0"

      # 浮动/平铺切换
      "CTRL ALT, up, exec, hyprctl dispatch focuswindow floating"
      "CTRL ALT, down, exec, hyprctl dispatch focuswindow tiled"

      # 媒体控制
      ", XF86AudioPlay, exec, playerctl play-pause"
      ", XF86AudioNext, exec, playerctl next"
      ", XF86AudioPrev, exec, playerctl previous"
      ", XF86AudioStop, exec, playerctl stop"

      # 工作区滚动（鼠标滚轮）
      "${mod}, mouse_down, workspace, e-1"
      "${mod}, mouse_up, workspace, e+1"

      # 帮助：显示键位
      "${mod}, F1, exec, show-keybinds"
    ];

    # === 鼠标绑定 ===
    bindm = [
      "${mod}, mouse:272, movewindow"   # 左键拖动
      "${mod}, mouse:273, resizewindow" # 右键调整大小
    ];
  };
}


