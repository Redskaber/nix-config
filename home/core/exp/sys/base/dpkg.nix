# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/dpkg.nix
# @author: redskaber
# @datetime: 2026-06-14
# @diractory: home::core::exp::sys::base::dpkg
# - https://nix-community.github.io/home/options.xhtml#opt-programs.eza.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with shared.upkgs; [ dpkg ];
}


