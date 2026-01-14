# @path: ~/projects/configs/nix-config/src/wm/hyprland/hyprlock.nix
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
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
        # fractional_scaling = 0;
      };

      background = [{
        blur_passes = 2;
        vibrancy_darkness = 0.0;
        color = "rgba(0, 0, 0, 0)";
      }];

      shape = [{
        size = "300, 50";
        rounding = 0;
        border_size = 2;
        color = "rgba(102, 92, 84, 85)";            # 0.33 * 255 ≈ 85
        border_color = "rgba(168, 153, 132, 242)";  # 0.95 * 255 ≈ 242

        position = "0, 120";
        halign = "center";
        valign = "bottom";
      }];

      label = [
        # Time
        {
          text = ''cmd[update:1000] echo "$(date +'%k:%M')"'';
          font_size = 115;
          font_family = "Maple Mono Bold";
          shadow_passes = 3;
          color = "rgba(235, 219, 178, 230)"; # 0.9 * 255 ≈ 230
          position = "0, -25";
          halign = "center";
          valign = "top";
        }
        # Date
        {
          text = ''cmd[update:1000] echo "- $(date +'%A, %B %d') -"'';
          font_size = 18;
          font_family = "Maple Mono";
          shadow_passes = 3;
          color = "rgba(235, 219, 178, 230)";
          position = "0, -225";
          halign = "center";
          valign = "top";
        }
        # Username
        {
          text = "  $USER";
          font_size = 15;
          font_family = "Maple Mono Bold";
          color = "rgba(235, 219, 178, 255)";
          position = "0, 134";
          halign = "center";
          valign = "bottom";
        }
      ];

      input-field = [{
        size = "300, 50";
        rounding = 0;
        outline_thickness = 2;
        dots_spacing = 0.4;
        font_color = "rgba(235, 219, 178, 230)";
        font_family = "Maple Mono Bold";
        outer_color = "rgba(168, 153, 132, 242)";
        inner_color = "rgba(102, 92, 84, 85)";
        check_color = "rgba(152, 151, 26, 242)";
        fail_color = "rgba(204, 36, 29, 242)";
        capslock_color = "rgba(215, 153, 33, 242)";
        bothlock_color = "rgba(215, 153, 33, 0.95)";

        hide_input = false;
        fade_on_empty = false;
        placeholder_text = ''<i><span foreground="##fbf1c7">Enter Password</span></i>'';

        position = "0, 50";
        halign = "center";
        valign = "bottom";
      }];

      animation = [ "inputFieldColors, 0" ];
    };
  };
}


