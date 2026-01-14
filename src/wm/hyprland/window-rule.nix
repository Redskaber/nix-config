# @path: ~/projects/configs/nix-config/src/wm/hyprland/window-rule.nix
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
{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      # Floating apps
      # "float, ^(imv|mpv|zenity|waypaper|SoundWireServer|.sameboy-wrapped|org.gnome.Calculator|org.gnome.FileRoller|org.pulseaudio.pavucontrol)$"

      # Pinned apps
      # "pin, ^(rofi|waypaper|Picture-in-Picture)$"

      # Tiled exceptions
      # "tile, ^(Aseprite)$"

      # Sizing & positioning
      # "size 850 500, ^(zenity)$"
      # "size 725 330, ^(SoundWireServer)$"
      # "size 700 450, title:^(Volume Control)$"
      # "move 40 55%, title:^(Volume Control)$"

      # Workspace assignments
      # "workspace 1, ^(zen)$"
      # "workspace 4, ^(Gimp-2.10|Aseprite)$"
      # "workspace 5, ^(Audacious|Spotify)$"
      # "workspace 8, ^(com.obsproject.Studio)$"
      # "workspace 10, ^(discord|WebCord|vesktop)$"

      # Idle inhibit
      # "idle_inhibit focus, ^(mpv|zen-beta)$"
      # "idle_inhibit focus, ^(zen)$"  # ← 改为 focus 更可靠

      # Dim around portals
      # "dim_around, ^(xdg-desktop-portal-gtk)$"
    ];

    # layerrule = [
    #   "dim_around, namespace:^(rofi|swaync-control-center)$"
    # ];

    workspace = [
      "w[tv1], gapsout:0, gapsin:0"
      "f[1], gapsout:0, gapsin:0"
    ];
  };
}


