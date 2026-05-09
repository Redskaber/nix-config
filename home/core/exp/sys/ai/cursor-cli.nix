# @path: ~/projects/configs/nix-config/home/core/exp/sys/ai/cursor-cli.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: home::core::exp::sys::ai::cursor-cli
# terminal: cursor-agent


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ cursor-cli ];


}


