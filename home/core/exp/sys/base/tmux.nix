# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/tmux.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::tmux
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.tmux.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  programs.tmux.enable = true;

  # Used user config:
  xdg.configFile."tmux" = {
    source = inputs.tmux-config;   # abs path
    recursive = true;              # rec-link
    force = true;
  };
}


