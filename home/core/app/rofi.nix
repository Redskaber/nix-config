# @path: ~/projects/configs/nix-config/home/core/app/rofi.nix
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
  home.packages = with pkgs; [ rofi ];

  xdg.configFile."rofi" = {
    source = inputs.rofi-config;    # abs path
    recursive = true;               # rec-link
    force = true;
  };

}


