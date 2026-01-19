# @path: ~/projects/configs/nix-config/nixos/core/compat.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::compat
# - nixos => non-nixos (compatiable)
# - optional mod
# - for me handle import references non-flake repo
# - ps: nvim-config is used xdg.configFile import, handle build and install path assue
# - warining: nix-ld un-sup 32 bit app

{ inputs
, config
, lib
, pkgs
, ...
}:
{

  # Compat: FileSystem
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.libc
    stdenv.cc.cc
    zlib
    openssl
    libffi
    gmp
    ncurses
  ];


  # Compat: Platform Windows
  # Wine:
  #   - initial: winecfg
  #   - win-con: wine control
  #   - win-cmd: wine cmd
  #   - win-run: wine <app>
  #   - win-exp: wine explorer
  #   - win-kall:wineserver -k
  #   - wine-ver: wine --version
  # winetricks:
  #   - install-depend: winetricks -q <depends-name>
  #     - corefonts (must)
  #     - vcrun2019 (visual-c++)
  #     - dotnet48  (.net-framework)
  #     - msxml6, riched20, gdiplus, ...
  # Add:
  #   wine-prefix to rc or env
  #   export WINEARCH=win64
  #   export WINEPREFIX=~/.wine
  environment.systemPackages = with pkgs; [
    wineWowPackages.waylandFull   # wayland
    winetricks
    corefonts
  ];


}


