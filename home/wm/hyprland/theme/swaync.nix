# @path: ~/projects/configs/nix-config/home/wm/hyprland/theme/swaync.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::wm::hyprland::theme::swaync
# - swaynotificationcenter
# - Notification Center and Notification Daemon for wayland


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
let
  swayncResult = shared.orc.mergeHomeFiles (
    shared.orc.listFilesRecursive inputs.swaync-config ""
  ) [
    { include = [ "wallust/colors-wallust.css" ];
      emitter = "copy";
      destPrefix = ".config/swaync"; }
  ];
in
{

  home.packages = with pkgs; [
    swaynotificationcenter
  ];

  xdg.configFile."swaync" = {
    source = inputs.swaync-config;  # abs path
    recursive = true;               # rec-link
    force = true;
  };
  home.activation.swayncWallust = lib.hm.dag.entryAfter [ "writeBoundary" ] swayncResult.activation;

}


