# @path: ~/projects/configs/nix-config/home/core/exp/app/re/imhex.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::re::imhex

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ imhex ];


}

