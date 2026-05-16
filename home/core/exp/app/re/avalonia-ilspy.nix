# @path: ~/projects/configs/nix-config/home/core/exp/app/re/avalonia-ilspy.nix
# @author: redskaber
# @datetime: 2026-05-15
# @description: home::core::exp::app::re::avalonia-ilspy
# .NET assembly browser and decompiler
# dotscope: Rust analyzing and reverse engineering

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ avalonia-ilspy ];


}


