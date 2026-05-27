# @path: ~/projects/configs/nix-config/nixos/wm/hyprland/plugins/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::wm::hyprland::plugins::default
#
## v26.05: 2026-05-26 00:23
# error: undefined variable 'hyprscrolling'
# at /home/kilig/projects/configs/nix-config/nixos/wm/hyprland/plugins/hyprscrolling.nix:16:5:
#     15|   environment.systemPackages = with pkgs.hyprlandPlugins; [
#     16|     hyprscrolling
#       |     ^
#     17|   ];
#

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = if shared.version.value == "26.05" then [] else [ ./hyprscrolling.nix ];


}


