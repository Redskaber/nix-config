# @path: ~/projects/configs/nix-config/home/core/sys/ripgrep.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: home::core::sys::ripgrep
# - https://nix-community.github.io/home/options.xhtml#opt-programs.ripgrep.enable


{ inputs
, lib
, config
, pkgs
, ...
}:
{

  programs.ripgrep.enable = true;


}


