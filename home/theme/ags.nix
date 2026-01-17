# @path: ~/projects/configs/nix-config/home/theme/ags.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::theme::ags
# - theme cli and custom tools


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ ags ];

  xdg.configFile."ags" = {
    source = inputs.ags-config;     # abs path
    recursive = true;               # rec-link
    force = true;
  };

}


