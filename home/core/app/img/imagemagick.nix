# @path: ~/projects/configs/nix-config/home/core/app/img/imagemagick.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::img::imagemagick
# - console image change


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ gimp ];

}


