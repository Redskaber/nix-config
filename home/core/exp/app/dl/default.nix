# @path: ~/projects/configs/nix-config/home/core/exp/app/dl/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::exp::app::dl::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./baidupcs-go.nix
    ./downloader.nix
    ./xunlei.nix
  ];


}


