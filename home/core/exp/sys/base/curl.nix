# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/curl.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::curl


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    curl
  ];

}


