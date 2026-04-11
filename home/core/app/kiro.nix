# @path: ~/projects/configs/nix-config/home/core/app/kiro.nix
# @author: redskaber
# @datetime: 2026-04-10
# @discription: home::core::app::kiro
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


