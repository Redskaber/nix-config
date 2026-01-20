# @path: ~/projects/configs/nix-config/home/core/app/steam.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app::steam


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  home.packages = [
    # (config.lib.nixGL.wrap pkgs.steam)  # non-nixos
    pkgs.steam
  ];
}

