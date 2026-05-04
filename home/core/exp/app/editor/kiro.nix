# @path: ~/projects/configs/nix-config/home/core/app/editor/kiro.nix
# @author: redskaber
# @datetime: 2026-04-10
# @description: home::core::app::editor::kiro
# - kiro    : IDE for Agentic AI workflows based on VS Code
# - kiro-fhs: Wrapped variant of kiro which launches in a FHS compatible environment,
#             should allow for easy usage of extensions without nix-specific modifications

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ kiro-fhs ];


}


