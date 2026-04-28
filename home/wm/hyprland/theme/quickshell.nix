# @path: ~/projects/configs/nix-config/home/wm/hyprland/theme/quickshell.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::wm::hyprland::theme::quickshell
# - It is a status bar developed with Qt Quick
# - qml
# - or used ags (unrecommend)

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
let
  quickResult = shared.orc.mergeHomeFiles (
    shared.orc.listFilesRecursive inputs.quickshell-config ""
  ) [
    { include = [ "qml_color.json" ];
      emitter = "copy";
      destPrefix = ".config/quickshell"; }
  ];
in
{
  home.packages = with pkgs; [ quickshell ];

  xdg.configFile."quickshell" = {
    source = inputs.quickshell-config;    # abs path
    recursive = true;                     # rec-link
    force = true;
  };
  home.activation.quickWallust = lib.hm.dag.entryAfter [ "writeBoundary" ] quickResult.activation;

}


