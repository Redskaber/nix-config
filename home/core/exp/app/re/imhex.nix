# @path: ~/projects/configs/nix-config/home/core/app/re/imhex.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app::re::imhex

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ imhex ];


}

