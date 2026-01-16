# @path: ~/projects/configs/nix-config/home/core/app/clash-verge-rev.nix
# @author: redskaber
# @datetime: 2025-12-12


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ clash-verge-rev ];

}


