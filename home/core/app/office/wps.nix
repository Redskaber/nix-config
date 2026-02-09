# @path: ~/projects/configs/nix-config/home/core/app/office/wps.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::office::wps
# - Office suite, formerly Kingsoft Office

{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [ wpsoffice ];

}



