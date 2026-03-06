# @path: ~/projects/configs/nix-config/home/wm/hyprland/theme/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::wm::hyprland::theme::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./qtct.nix
    ./quickshell.nix
    ./rofi.nix
    ./satty.nix
    ./swaync.nix
    ./swayosd.nix
    ./wallust.nix
    ./waybar.nix
    ./wlogout.nix
  ];


}


