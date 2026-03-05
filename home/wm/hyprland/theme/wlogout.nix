# @path: ~/projects/configs/nix-config/home/wm/hyprland/theme/wlogout.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::wm::hyprland::theme::wlogout
# - A graphical logout/shutdown menu tool designed specifically for
#   Wayland desktop environments (such as Hyprland and Sway).


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [ wlogout ];

  xdg.configFile."wlogout" = {
    source = inputs.wlogout-config;   # abs path
    recursive = true;                 # rec-link
    force = true;
  };

}


