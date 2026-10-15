# @path: ~/projects/configs/nix-config/home/core/exp/app/game/lutris.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app:lutris
# - nixos used manager your games

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
# wine/lutris is a Linux gaming stack; desktopEntries likewise live in
# Linux desktop environments. darwin App bundles own that land. (Body
# under `config = mkIf` — module-position mkIf is illegal.)
{
  config = lib.mkIf shared.caps.linux-family {
    # Windows compat via wine (winecfg / wine cmd / wine explorer;
    # wineserver -k kills a stuck session).
    home.packages = with pkgs; [
      lutris
      (shared.version.value.wine pkgs)
    ];

    xdg.desktopEntries.lutris = {
      name = "Lutris";
      exec = "lutris";
      icon = "lutris";
      categories = [ "Game" ];
    };

  };
}
