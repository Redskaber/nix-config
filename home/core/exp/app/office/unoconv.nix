# @path: ~/projects/configs/nix-config/home/core/exp/app/office/unoconv.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::office::unoconv
# - Convert between any document format supported by LibreOffice/OpenOffice

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ unoconv ];

}



