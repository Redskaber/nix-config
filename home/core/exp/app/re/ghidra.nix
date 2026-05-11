# @path: ~/projects/configs/nix-config/home/core/exp/app/re/ghidra.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::re::ghidra

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ ghidra ];


}

