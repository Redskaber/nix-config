# @path: ~/projects/configs/nix-config/home/env/base/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::env::base::default

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [
    llvmPackages_22.clang
    llvmPackages_22.clang-tools
    llvmPackages_22.lld

    gcc16
    gdb
    cmake

    rustc
    cargo
    python314
    nodejs_26

    file
    valgrind
    strace
    ltrace
    pciutils
    vulkan-tools
  ];
}


