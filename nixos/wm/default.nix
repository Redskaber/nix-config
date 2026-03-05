# @path: ~/projects/configs/nix-config/nixos/wm/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::wm::default


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    # ./gnome
    # ./hyprland
    ./niri
  ];


}


