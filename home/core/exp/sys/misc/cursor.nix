# @path: ~/projects/configs/nix-config/home/core/exp/sys/misc/cursor.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: home::core::exp::sys::misc::cursor
# @directory: https://search.nixos.org/options?channel=25.11&query=home.pointerCursor.&source=home_manager#show=home-manager-option%253Ahome.pointerCursor
# Cursor themes available in bibata-cursors (Modern/Original ×
# Amber/Classic/Ice, plus -Right variants) — enumerate with:
#   ❯ la $(nix-build '<nixpkgs>' --no-out-link -A bibata-cursors)/share/icons/

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
# Cursor themes ride X11/GTK/Wayland — darwin owns its cursor via
# Aqua; skip the whole module on darwin. (module-position mkIf is
# illegal: body under `config = mkIf`.)
{
  config = lib.mkIf shared.caps.linux-family {

    home.pointerCursor = {
      enable = true;
      package = pkgs.bibata-cursors; # capitaine-cursors
      name = shared.pointer-cursor.tag;
      size = 24;

      x11.enable = true;
      gtk.enable = true;
      dotIcons.enable = true;
      hyprcursor.enable = true;
      sway.enable = false;
    };

    xdg.dataFile."icons/default/index.theme".force = true;

  };
}
