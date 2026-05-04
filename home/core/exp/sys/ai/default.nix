# @path: ~/projects/configs/nix-config/home/core/exp/sys/ai/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::ai::default

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./claude-code.nix
    ./opencode.nix
    ./gemini-cli.nix
  ];


}


