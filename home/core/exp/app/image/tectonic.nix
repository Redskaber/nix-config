# @path: ~/projects/configs/nix-config/home/core/app/img/tectonic.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::img::tectonic
# rander LaTeX

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ tectonic ];

}


