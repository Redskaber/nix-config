# @path: ~/projects/configs/nix-config/home/core/app/emacs.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.emacs.enable


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

