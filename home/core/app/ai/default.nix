# @path: ~/projects/configs/nix-config/home/core/app/ai/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app::ai::default

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


