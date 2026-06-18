# @path: ~/projects/configs/nix-config/home/core/exp/app/reader/default.nix
# @author: redskaber
# @datetime: 2026-05-22
# @description: home::core::exp::app::reader::default

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./koodo-reader.nix
    ./librum.nix
    ./z-library.nix
  ];

}


