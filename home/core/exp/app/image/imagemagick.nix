# @path: ~/projects/configs/nix-config/home/core/exp/app/img/imagemagick.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::img::imagemagick
# - console image change


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ imagemagick ];

}


