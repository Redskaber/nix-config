# @path: ~/projects/configs/nix-config/home/core/sys/yq.nix
# @author: redskaber
# @datetime: 2026-04-19
# @discription: home::core::sys::yq
# - terminal data yaml/toml/xml ser; jq wrapper


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ yq-go ];

}


