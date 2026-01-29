# @path: ~/projects/configs/nix-config/home/core/sys/debug.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::sys::debug


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    valgrind
    strace
    ltrace
    pciutils
    vulkan-tools
  ];

}

