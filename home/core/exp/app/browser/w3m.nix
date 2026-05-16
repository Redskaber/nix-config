# @path: ~/projects/configs/nix-config/home/core/exp/app/browser/w3m.nix
# @author: redskaber
# @datetime: 2026-04-18
# @description: home::core::exp::app::browser::w3m
# - terminal web browser

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    w3m
  ];

}


