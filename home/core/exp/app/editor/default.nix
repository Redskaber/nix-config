# @path: ~/projects/configs/nix-config/home/core/exp/app/editor/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::exp::app::editor::default
#
# Routing mode (mode B: multi-select routing):
#   Selects editor modules based on shared.editors list.
#   Same pattern as nixos/core/drive/default.nix.


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = builtins.map (e: ./${e}.nix) shared.editors;
}
