# @path: ~/projects/configs/nix-config/nixos/core/exp/xwayland.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: nixos::core::exp::xwayland

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  # system manager
  programs.xwayland = {
    enable = true;
  };


}


