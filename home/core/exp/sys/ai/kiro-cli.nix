# @path: ~/projects/configs/nix-config/home/core/exp/sys/ai/kiro-cli.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::ai::kiro-cli

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ kiro-cli ];


}


