# @path: ~/projects/configs/nix-config/home/core/app/terminal/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::app::terminal::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./kitty.nix
    ./wezterm.nix
  ];


}


