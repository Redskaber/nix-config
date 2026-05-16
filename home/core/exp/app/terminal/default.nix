# @path: ~/projects/configs/nix-config/home/core/exp/app/terminal/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::exp::app::terminal::default


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


