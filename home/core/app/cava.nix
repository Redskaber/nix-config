# @path: ~/projects/configs/nix-config/home/core/app/cava.nix
# @author: redskaber
# @datetime: 2025-12-12
# @directory: https://nix-community.github.io/home-manager/options.xhtml


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


