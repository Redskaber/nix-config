# @path: ~/projects/configs/nix-config/home/core/exp/app/editor/zcode.nix
# @author: redskaber
# @datetime: 2026-08-04
# @discription: home::core::exp::app::editor::zcode

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with shared.upkgs; [
    inputs.zcode.packages.${shared.arch.tag}.default
  ];

}



