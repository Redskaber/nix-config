# @path: ~/projects/configs/nix-config/home/core/exp/sys/re/ilspycmd.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::re::ilspycmd
# - Tool for decompiling .NET assemblies and generating portable PDBs


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ ilspycmd ];

}


