# @path: ~/projects/configs/nix-config/home/core/exp/sys/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./ai
    ./base
    ./compat
    ./fs
    ./media
    ./misc
    ./monitor
    ./shell
  ];


}


