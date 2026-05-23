# @path: ~/projects/configs/nix-config/home/core/exp/app/video/ani-cli.nix
# @author: redskaber
# @datetime: 2026-05-15
# @description: home::core::exp::app::video::ani-cli
# A cli tool to browse and play anime


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ ani-cli ];

}


