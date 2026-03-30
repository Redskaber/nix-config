# @path: ~/projects/configs/nix-config/home/wm/hyprland/theme/waybar.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::wm::hyprland::theme::waybar
# - this file is window status-bar


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [ waybar ];

  xdg.configFile."waybar" = {
    source = inputs.waybar-config;  # abs path
    recursive = true;               # rec-link
    force = true;
  };

}


