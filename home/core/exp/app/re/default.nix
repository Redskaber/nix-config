# @path: ~/projects/configs/nix-config/home/core/app/re/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app::re::default

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./cutter.nix
    ./ghidra.nix
    ./imhex.nix
  ];

}


