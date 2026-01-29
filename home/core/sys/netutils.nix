# @path: ~/projects/configs/nix-config/home/core/sys/netutils.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::sys::netutils


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    curl wget
  ];

}


