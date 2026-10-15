# @path: ~/projects/configs/nix-config/home/core/exp/app/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::exp::app::default
#
# Routing mode (multi-select): selects app CATEGORY TREES from the
# shared.app-set row — a lean host stops merging whole grab-bag trees
# instead of paying the module-system fixed cost per leaf. The
# browser/editor/terminal categories ride every row (they self-prune
# through their own sets). The full row's ORDER is load-bearing for
# the full host's drv hash (merge order feeds home.packages concat
# order) — pinned by the enum test, see lib/shared/lang/enum.nix.

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
