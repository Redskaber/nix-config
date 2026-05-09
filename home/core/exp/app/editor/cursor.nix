# @path: ~/projects/configs/nix-config/home/core/exp/app/editor/cursor.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: home::core::exp::app::editor::cursor
# - cursor  : AI-powered code editor built on vscode
# - kiro-fhs: Wrapped variant of cursor which launches in a FHS compatible environment,
#             should allow for easy usage of extensions without nix-specific modifications


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ code-cursor-fhs ];


}


