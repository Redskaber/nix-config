# @path: ~/projects/configs/nix-config/home/core/app/ai/opencode.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app::ai::opencode

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ opencode ];


}


