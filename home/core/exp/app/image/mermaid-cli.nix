# @path: ~/projects/configs/nix-config/home/core/app/img/mermaid-cli.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::img::mermaid-cli

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ mermaid-cli ];

}


