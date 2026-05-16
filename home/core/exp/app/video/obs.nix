# @path: ~/projects/configs/nix-config/home/core/exp/app/obs.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::obs

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  # Used user config:
  xdg.configFile."obs-studio/plugin_config/input-overlay" = {
    source = inputs.input-overlay-config; # abs path
    recursive = true;                     # rec-link
    force = true;
  };

}


