# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/ripgrep.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::base::ripgrep
# - https://nix-community.github.io/home/options.xhtml#opt-programs.ripgrep.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  programs.ripgrep.enable = true;


}


