# @path: ~/projects/configs/nix-config/home/core/exp/app/browser/default.nix
# @author: redskaber
# @datetime: 2026-05-15
# @description: home::core::exp::app::browser::default
#
# Routing mode (mode B: multi-select routing):
#   Selects browser modules based on shared.browsers list.

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = builtins.map (b: ./${b}.nix) shared.browsers;
}
