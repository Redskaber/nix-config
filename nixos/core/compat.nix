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

}


