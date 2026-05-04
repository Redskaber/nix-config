# @path: ~/projects/configs/nix-config/home/core/exp/sys/ai/claude-code.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::ai::claude-code

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ claude-code claude-code-router ];


}

