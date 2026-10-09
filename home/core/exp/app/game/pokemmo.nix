# @path: ~/projects/configs/nix-config/home/core/exp/app/game/pokemmo.nix
# @author: redskaber
# @datetime: 2026-10-07
# @description: home::core::exp::app::game::pokemmo
# - Installer and Launcher for the PokeMMO emulator

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{

  home.packages = with shared.upkgs; [

  ];

}
