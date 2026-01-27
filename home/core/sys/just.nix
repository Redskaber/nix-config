# @path: ~/projects/configs/nix-config/home/core/sys/just.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::sys::just
# - Handy way to save and run project-specific commands


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    just
  ];

}


