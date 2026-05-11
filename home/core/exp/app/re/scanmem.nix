# @path: ~/projects/configs/nix-config/home/core/exp/app/re/scanmem.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: home::core::exp::app::re::scanmem

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ scanmem ];


}

