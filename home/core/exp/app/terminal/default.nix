# @path: ~/projects/configs/nix-config/home/core/exp/app/terminal/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::exp::app::terminal::default
#
# Routing mode (mode B: multi-select routing):
#   Selects terminal modules based on shared.terminals list.


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = builtins.map (t: ./${t}.nix) shared.terminals;
}
