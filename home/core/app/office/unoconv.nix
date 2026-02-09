# @path: ~/projects/configs/nix-config/home/core/app/office/unoconv.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::office::unoconv
# - Convert between any document format supported by LibreOffice/OpenOffice

{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [ unoconv ];

}



