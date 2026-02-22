# @path: ~/projects/configs/nix-config/home/core/app/ra/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::ra::default


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [
    scanmem
  ];

}

