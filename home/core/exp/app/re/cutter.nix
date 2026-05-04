# @path: ~/projects/configs/nix-config/home/core/app/re/cutter.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app::re::cutter

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ cutter ];


}

