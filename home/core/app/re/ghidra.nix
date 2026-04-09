# @path: ~/projects/configs/nix-config/home/core/app/re/ghidra.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app::re::ghidra

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ ghidra ];


}

