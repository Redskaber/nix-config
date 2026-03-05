# @path: ~/projects/configs/nix-config/home/wm/hyprland/theme/wallust.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::wm::hyprland::theme::wallust
# - Modern wallpaper and color scheme generator


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [ wallust ];

  xdg.configFile."wallust" = {
    source = inputs.wallust-config;   # abs path
    recursive = true;                 # rec-link
    force = true;
  };

}



