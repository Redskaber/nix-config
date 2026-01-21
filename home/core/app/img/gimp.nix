# @path: ~/projects/configs/nix-config/home/core/app/img/gimp.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::img::gimp
# - open source image edit


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ gimp ];

}


