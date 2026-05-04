# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/fastfetch.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::base::fastfetch
# - https://nix-community.github.io/home/options.xhtml#opt-programs.fastfetch.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  programs.fastfetch.enable = true;

  # Used user config:
  xdg.configFile."fastfetch" = {
    source = inputs.fastfetch-config;   # abs path
    recursive = true;                   # rec-link
    force = true;
  };
}


