# @path: ~/projects/configs/nix-config/home/core/sys/shell/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::sys::shell::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./fish.nix
    ./zsh.nix
  ];


}


