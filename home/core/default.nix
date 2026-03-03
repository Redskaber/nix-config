# @path: ~/projects/configs/nix-config/home/core/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::default



{ inputs
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./app
    ./srv
    ./sys
  ];


}


