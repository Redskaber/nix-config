# @path: ~/projects/configs/nix-config/home/core/exp/app/re/cutter.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::re::cutter
# use `nixpkgs-unstable.overlays.patches.cutter_patched`

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ cutter_patched ];


}

