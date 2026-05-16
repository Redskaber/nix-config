# @path: ~/projects/configs/nix-config/home/core/exp/app/misc/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::exp::app::misc::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./showmethekey.nix
  ];


}


