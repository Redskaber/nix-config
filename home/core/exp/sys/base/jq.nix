# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/jq.nix
# @author: redskaber
# @datetime: 2026-05-05
# @directory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.jq.enable
# @description: home::core::exp::sys::base::jq
# - terminal data json set


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  programs.jq.enable = true;

}


