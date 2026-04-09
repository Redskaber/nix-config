# @path: ~/projects/configs/nix-config/home/core/app/ai/gemini-cli.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app::ai::gemini-cli

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ gemini-cli ];


}


