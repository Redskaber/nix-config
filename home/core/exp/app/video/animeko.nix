# @path: ~/projects/configs/nix-config/home/core/exp/app/video/animeko.nix
# @author: redskaber
# @datetime: 2026-05-15
# @description: home::core::exp::app::video::animeko
# One-stop platform for finding, following and watching anime


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ animeko ];

}


