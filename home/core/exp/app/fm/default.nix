# @path: ~/projects/configs/nix-config/home/core/app/fm/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::app::fm::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./nemo.nix
  ];


}


