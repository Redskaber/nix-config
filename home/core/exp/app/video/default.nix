# @path: ~/projects/configs/nix-config/home/core/app/video/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::app::video::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./obs.nix
  ];


}


