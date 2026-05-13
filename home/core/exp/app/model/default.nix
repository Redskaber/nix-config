# @path: ~/projects/configs/nix-config/home/core/exp/app/model/default.nix
# @author: redskaber
# @datetime: 2026-05-14
# @description: home::core::exp::app::model::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./blender.nix
  ];


}


