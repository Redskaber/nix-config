# @path: ~/projects/configs/nix-config/home/core/sys/wl-clipboard.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::sys::wl-clipboard
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.uv.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [
    cliphist
    wl-clipboard    # command-line
    wl-clip-persist
  ];
}

