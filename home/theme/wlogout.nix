# @path: ~/projects/configs/nix-config/home/theme/wlogout.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::theme::wlogout
# - A graphical logout/shutdown menu tool designed specifically for
#   Wayland desktop environments (such as Hyprland and Sway).


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [ wlogout ];

  xdg.configFile."wlogout" = {
    source = inputs.wlogout-config;   # abs path
    recursive = true;                 # rec-link
    force = true;
  };

}


