# @path: ~/projects/configs/nix-config/home/wm/niri/theme/default.nix
# @author: redskaber
# @datetime: 2026-03-05
# @description: home::wm::niri::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./satty.nix
    ./swaylock.nix
    ./swaync.nix
    ./swayosd.nix
    ./waybar.nix
    ./wlogout.nix
  ];


}


