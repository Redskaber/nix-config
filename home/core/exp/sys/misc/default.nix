# @path: ~/projects/configs/nix-config/home/core/exp/sys/misc/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::misc::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./cava.nix
  ];

}


