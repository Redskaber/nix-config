# @path: ~/projects/configs/nix-config/home/core/exp/app/lutris.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app:lutris
# - nixos used manager your games


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
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
    (if shared.version == shared.enum.version.v25_11
     then wineWowPackages.waylandFull
     else wineWow64Packages.waylandFull)
  ];

  # Optional: auto create decktop icon
  xdg.desktopEntries.lutris = {
    name = "Lutris";
    exec = "lutris";
    icon = "lutris";
    categories = [ "Game" ];
  };

}



