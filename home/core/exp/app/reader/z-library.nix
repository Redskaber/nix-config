# @path: ~/projects/configs/nix-config/home/core/exp/app/reader/z-library.nix
# @author: redskaber
# @datetime: 2026-06-14
# @description: home::core::exp::app::reader::z-library

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ 
    inputs.z-library.packages.${shared.arch.tag}.default
  ];

}


