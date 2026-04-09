# @path: ~/projects/configs/nix-config/home/core/app/ai/claude-code.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app::ai::claude-code

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

