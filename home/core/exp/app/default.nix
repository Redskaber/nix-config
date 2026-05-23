# @path: ~/projects/configs/nix-config/home/core/exp/app/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::exp::app::default



{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./browser
    ./dl
    ./editor
    ./fm
    ./game
    ./im
    ./image
    ./misc
    ./model
    ./music
    ./note
    ./office
    ./re
    ./reader
    ./terminal
    ./video
  ];


}


