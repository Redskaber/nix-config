# @path: ~/projects/configs/nix-config/home/wm/hyprland/theme/swaync.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::wm::hyprland::theme::swaync
# - swaynotificationcenter
# - Notification Center and Notification Daemon for wayland

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
let
  # T28 (orc consumption contract): the swaync-config tree carries no
  # `wallust/colors-wallust.css` placeholder yet, so the include below
  # matched nothing and this activation was an empty no-op — the silent
  # failure mode the 99th test (tests/lib/shared/orc.nix) now locks
  # out. wallust.toml declares swaync.target =
  # ~/.config/swaync/wallust/colors-wallust.css, and the runtime write
  # needs a real writable file (plus its parent dir) planted at
  # activation — the same job the other six copy-emitter sites do with
  # committed placeholders (waybar/rofi/kitty/cava/quickshell/hypr).
  # Until the config repo grows the placeholder, the plant source is
  # the wallust template itself (the file wallust renders for swaync);
  # the merge order below keeps the TREE entry winning the moment it
  # exists, so this synthesis retires on its own — no maintenance, no
  # call-site conditional. The remaining breakage lives repo-side
  # (style.css @imports the RAW template instead of the planted target)
  swayncWallustFileMap = {
    "wallust/colors-wallust.css" = {
      absPath = inputs.wallust-config + "/templates/colors-swaync.css";
      type = "regular";
    };
  }
  // shared.orc.listFilesRecursive inputs.swaync-config "";

  swayncResult = shared.orc.mergeHomeFiles swayncWallustFileMap [
    {
      include = [ "wallust/colors-wallust.css" ];
      emitter = "copy";
      destPrefix = ".config/swaync";
    }
  ];
in
{

  home.packages = with pkgs; [
    swaynotificationcenter
  ];

  xdg.configFile."swaync" = {
    source = inputs.swaync-config; # abs path
    recursive = true; # rec-link
    force = true;
  };
  home.activation.swayncWallust = lib.hm.dag.entryAfter [ "writeBoundary" ] swayncResult.activation;

}
