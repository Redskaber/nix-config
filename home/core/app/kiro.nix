# @path: ~/projects/configs/nix-config/home/core/app/kiro.nix
# @author: redskaber
# @datetime: 2026-04-10
# @discription: home::core::app::kiro
# - IDE for Agentic AI workflows based on VS Code

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ kiro ];


}


