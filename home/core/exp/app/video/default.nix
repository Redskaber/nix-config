# @path: ~/projects/configs/nix-config/home/core/exp/app/video/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::exp::app::video::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./ani-cli.nix
    # ./animeko.nix
    ./kazumi.nix
    ./obs.nix
    ./viu.nix
  ];


}


