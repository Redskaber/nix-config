# @path: ~/projects/configs/nix-config/home/wm/hyprland/theme/waybar.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::wm::hyprland::theme::waybar
# - this file is window status-bar


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
let
  waybarResult = shared.orc.mergeHomeFiles (
    shared.orc.listFilesRecursive inputs.waybar-config ""
  ) [
    { include = [ "wallust/colors-waybar.css" ];
      emitter = "copy";
      destPrefix = ".config/waybar"; }
  ];
in
{

  home.packages = with shared.upkgs; [ waybar ];

  xdg.configFile."waybar" = {
    source = inputs.waybar-config;  # abs path
    recursive = true;               # rec-link
    force = true;
  };
  home.activation.waybarWallust = lib.hm.dag.entryAfter [ "writeBoundary" ] waybarResult.activation;

}


