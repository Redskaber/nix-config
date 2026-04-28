# @path: ~/projects/configs/nix-config/home/wm/hyprland/theme/rofi.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::wm::hyprland::theme::rofi
# - Run-Dialog , window-swicher


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
let
  rofiResult = shared.orc.mergeHomeFiles (
    shared.orc.listFilesRecursive inputs.rofi-config ""
  ) [
    { include = [ "wallust/colors-rofi.rasi" ];
      emitter = "copy";
      destPrefix = ".config/rofi"; }
  ];
in
{
  home.packages = with pkgs; [ rofi ];

  xdg.configFile."rofi" = {
    source = inputs.rofi-config;    # abs path
    recursive = true;               # rec-link
    force = true;
  };
  home.activation.rofiWallust = lib.hm.dag.entryAfter [ "writeBoundary" ] rofiResult.activation;

}


