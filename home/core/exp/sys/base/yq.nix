# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/yq.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::yq
# - terminal data yaml/toml/xml set; jq wrapper


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


