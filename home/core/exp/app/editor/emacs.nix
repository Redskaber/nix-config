# @path: ~/projects/configs/nix-config/home/core/exp/app/editor/emacs.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.emacs.enable
# @description: home::core::exp::app::editor::emacs


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  programs.emacs = {
    enable = true;
    package = pkgs.emacs;
  };

  # Used user config:
  xdg.configFile."emacs" = {
    source = inputs.emacs-config;   # abs path
    recursive = true;               # rec-link
    force = true;
  };


}

