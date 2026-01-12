# @path: ~/projects/configs/nix-config/src/core/app/steam.nix
# @author: redskaber
# @datetime: 2025-12-12


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  home.packages = [
    pkgs.steam
  ];
}

