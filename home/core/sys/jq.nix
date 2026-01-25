# @path: ~/projects/configs/nix-config/home/core/sys/jq.nix
# @author: redskaber
# @datetime: 2025-12-12
# @directory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.jq.enable
# @discription: home::core::sys::jq
# - terminal data json ser


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  progorams.jq.enable = true;

}


