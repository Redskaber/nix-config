# @path: ~/projects/configs/nix-config/src/wm/hyprland/hyprland.nix
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
  home.packages = with pkgs; [
    swww
    grimblast
    hyprpicker
    grim
    slurp
    wl-clip-persist
    cliphist
    wf-recorder
  ];

  # hyprland through system enable
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    systemd = {
      enable = true;
      enableXdgAutostart = true;    # auto-enable: ~/.config/autostart/
    };
  };
}


