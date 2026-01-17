# @path: ~/projects/configs/nix-config/home/theme/rofi.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::theme::rofi
# - Run-Dialog , window-swicher


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


