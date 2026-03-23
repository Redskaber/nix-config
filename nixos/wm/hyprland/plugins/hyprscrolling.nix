# @path: ~/projects/configs/nix-config/nixos/wm/hyprland/plugins/hyprscrolling.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::wm::hyprland::plugins::hyprscrolling


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs.hyprlandPlugins; [
    hyprscrolling
  ];


}


