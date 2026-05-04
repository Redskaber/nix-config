# @path: ~/projects/configs/nix-config/home/core/exp/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./app
    ./sys
  ];


}


