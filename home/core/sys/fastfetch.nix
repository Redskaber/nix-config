# @path: ~/projects/configs/nix-config/home/core/sys/fastfetch.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: home::core::sys::fastfetch
# - https://nix-community.github.io/home/options.xhtml#opt-programs.fastfetch.enable


{ inputs
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


