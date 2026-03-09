# @path: ~/projects/configs/nix-config/nixos/core/exp/clash-verge.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::exp::clash-verge
# - google-chrome-stable --proxy-server=127.0.0.1:7897

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  # system manager
  programs.clash-verge = {
    enable = true;
    autoStart = false;
    serviceMode = true;
    tunMode = true;
    package = pkgs.clash-verge-rev;
  };


}


