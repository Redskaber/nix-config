# @path: ~/projects/configs/nix-config/home/core/app/office/pandoc.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::office::pandoc
# - Conversion between documentation formats

{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    pandoc
    texliveMinimal
  ];

}



