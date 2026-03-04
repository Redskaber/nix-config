# @path: ~/projects/configs/nix-config/home/theme/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::theme::default



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
    ./rofi.nix
    ./satty.nix
    ./swaylock.nix
    ./swaync.nix
    ./swayosd.nix
    ./wallust.nix
    ./waybar.nix
    ./wlogout.nix
  ];


}


