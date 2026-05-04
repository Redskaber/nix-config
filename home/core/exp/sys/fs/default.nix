# @path: ~/projects/configs/nix-config/home/core/exp/sys/fs/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::fs::default

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./compress.nix
    ./duf.nix
  ];

}


