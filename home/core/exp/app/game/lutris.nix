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
# T3.2: wine/lutris is a Linux gaming stack; desktopEntries likewise
# live in Linux desktop environments. macOS App bundles own that land.
# (Body under `config = mkIf` — module-position mkIf is illegal.)
{
  config = lib.mkIf shared.caps.linux-family {
    # Compat: Platform Windows
    # Wine:
    #   - initial: winecfg
    #   - win-con: wine control
    #   - win-cmd: wine cmd
    #   - win-run: wine <app>
    #   - win-exp: wine explorer
    #   - win-kall:wineserver -k
    #   - wine-ver: wine --version
    home.packages = with pkgs; [
      lutris
      (shared.version.value.wine pkgs)
    ];

    # Optional: auto create decktop icon
    xdg.desktopEntries.lutris = {
      name = "Lutris";
      exec = "lutris";
      icon = "lutris";
      categories = [ "Game" ];
    };

  };
}
