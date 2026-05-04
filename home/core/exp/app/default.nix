# @path: ~/projects/configs/nix-config/home/core/app/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::app::default



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
    ./music
    ./note
    ./office
    ./re
    ./terminal
    ./video
  ];


}


