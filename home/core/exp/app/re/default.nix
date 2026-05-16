# @path: ~/projects/configs/nix-config/home/core/exp/app/re/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::re::default

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./avalonia-ilspy.nix
    ./cutter.nix
    ./ghidra.nix
    ./imhex.nix
    ./pince.nix
    ./scanmem.nix
  ];

}


