# @path: ~/projects/configs/nix-config/home/core/exp/sys/ai/pi-coding-agent.nix
# @author: redskaber
# @datetime: 2026-07-20
# @description: home::core::exp::sys::ai::pi-coding-agent

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.unpkgs; [ pi-coding-agent ];

}

