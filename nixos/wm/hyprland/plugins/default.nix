# @path: ~/projects/configs/nix-config/nixos/wm/hyprland/plugins/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::wm::hyprland::plugins::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./hyprscrolling.nix
  ];


}


