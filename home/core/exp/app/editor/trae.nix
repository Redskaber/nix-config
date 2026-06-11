# @path: ~/projects/configs/nix-config/home/core/exp/app/editor/trae.nix
# @author: redskaber
# @datetime: 2026-05-31
# @description: home::core::exp::app::editor::trae
# Trae AI IDE for NixOS / Nix

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [
    inputs.trae.packages.${shared.arch.tag}.default
  ];


}


