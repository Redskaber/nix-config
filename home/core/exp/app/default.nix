# @path: ~/projects/configs/nix-config/home/core/exp/app/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::exp::app::default
#
# Routing mode (mode B: multi-select routing):
#   Selects app CATEGORY TREES from the shared.app-set row (T5.10,
#   demand-driven module loading) — same shape as the browser/editor/
#   terminal routers one level down, but the payload selects trees,
#   not leaves: a lean host stops merging desktop grab-bag modules
#   entirely instead of paying the module-system fixed cost per leaf.
#   The browser/editor/terminal categories ride every row of the
#   enum (they self-prune through their own sets); the ORDER of the
#   full row is load-bearing for the full host's drv hash (module
#   merge order feeds home.packages concat order) — pinned by the
#   enum test, see lib/shared/lang/enum.nix.

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = builtins.map (c: ./${c}) shared.appCategories;
}
