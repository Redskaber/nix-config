# @path: ~/projects/configs/nix-config/home/core/app/img/ghostscript.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::img::ghostscript

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


