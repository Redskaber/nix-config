# @path: ~/projects/configs/nix-config/home/core/app/zed.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::zed

{ inputs
, lib
, config
, pkgs
, ...
}:
{
  programs.zed-editor = {
    enable = true;
    package = pkgs.zed-editor;
    # extensions = [];
    # extraPackages = [];
    # installRemoteServer = false;
    # mutableUserDebug = true;
    # mutableUserKeymaps = true;
    # mutableUserSettings = true;
    # mutableUserTasks = true;
    # themes = {};
    # userDebug = [];
    # userKeymaps = [];
    # userSettings = {};
    # userTasks = [];
  };

}


