# @path: ~/projects/configs/nix-config/home/wm/niri/default.nix
# @author: redskaber
# @datetime: 2026-03-05
# @diractory: https://nix-community.github.io/home-manager/options.xhtml
# - niri user custom configurations
# TODO: waiting workspace custom design


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./theme
  ];

  home.packages = with pkgs; [
    alacritty       # niri default terminal
    fuzzel          # niri default app nemu
    # swaylock      # niri default window lock
    orca            # niri default window reader
    brightnessctl   # niri default light-changer
  ];


}


