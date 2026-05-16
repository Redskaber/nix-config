# @path: ~/projects/configs/nix-config/home/core/exp/app/office/wps.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::office::wps
# - Office suite, formerly Kingsoft Office

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ wpsoffice ];

}



