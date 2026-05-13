# @path: ~/projects/configs/nix-config/home/core/exp/app/model/blender.nix
# @author: redskaber
# @datetime: 2026-05-14
# @description: home::core::exp::app::model::blender


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with shared.upkgs; [ blender ];

}


