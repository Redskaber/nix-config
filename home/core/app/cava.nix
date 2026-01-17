# @path: ~/projects/configs/nix-config/home/core/app/cava.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app:cava
# - terminal visucalizer audio


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ cava ];

  xdg.configFile."cava" = {
    source = inputs.cava-config;    # abs path
    recursive = true;               # rec-link
    force = true;
  };

}


