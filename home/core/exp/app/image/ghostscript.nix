# @path: ~/projects/configs/nix-config/home/core/exp/app/img/ghostscript.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::img::ghostscript

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ ghostscript ];

}


