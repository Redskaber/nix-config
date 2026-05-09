# @path: ~/projects/configs/nix-config/home/core/exp/sys/misc/cursor.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: home::core::exp::sys::misc::cursor
# @directory: https://search.nixos.org/options?channel=25.11&query=home.pointerCursor.&source=home_manager#show=home-manager-option%253Ahome.pointerCursor
# Cursor-Theme:
#   ❯ la $(nix-build '<nixpkgs>' --no-out-link -A bibata-cursors)/share/icons/
# Base:
#   Bibata-Modern-Amber
#   Bibata-Modern-Amber-Right
#   Bibata-Modern-Classic
#   Bibata-Modern-Classic-Right
#   Bibata-Modern-Ice
#   Bibata-Modern-Ice-Right
#   Bibata-Original-Amber
#   Bibata-Original-Amber-Right
#   Bibata-Original-Classic
#   Bibata-Original-Classic-Right
#   Bibata-Original-Ice
#   Bibata-Original-Ice-Right
#
# Session-Level


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;    # capitaine-cursors
    name = shared.pointer-cursor.tag;
    size = 24;

    x11.enable = true;
    gtk.enable = true;
    dotIcons.enable = true;
    hyprcursor.enable = true;
    sway.enable = false;
  };

  xdg.dataFile."icons/default/index.theme".force = true;


}


