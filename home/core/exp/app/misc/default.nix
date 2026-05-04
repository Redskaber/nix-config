# @path: ~/projects/configs/nix-config/home/core/app/misc/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::app::misc::default


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


