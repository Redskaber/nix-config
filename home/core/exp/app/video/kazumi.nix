# @path: ~/projects/configs/nix-config/home/core/exp/app/video/kazumi.nix
# @author: redskaber
# @datetime: 2026-05-15
# @description: home::core::exp::app::video::kazumi


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ kazumi ];

}


