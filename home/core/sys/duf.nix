# @path: ~/projects/configs/nix-config/home/core/sys/duf.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::sys::duf
# - terminal data json ser


{ inputs
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [
    duf
  ];


}


