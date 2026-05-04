# @path: ~/projects/configs/nix-config/home/core/app/editor/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::app::editor::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./emacs.nix
    ./kiro.nix
    ./nvim.nix
    ./vscode.nix
    ./zed.nix
  ];


}


