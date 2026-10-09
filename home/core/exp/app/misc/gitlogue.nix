# @path: ~/projects/configs/nix-config/home/core/exp/app/misc/gitlogue.nix
# @author: redskaber
# @datetime: 2026-09-29
# @discription: home::core::exp::app::misc::gitlogue

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with shared.upkgs; [ gitlogue ];

}
