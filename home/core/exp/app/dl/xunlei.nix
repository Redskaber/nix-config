# @path: ~/projects/configs/nix-config/home/core/exp/app/xunlei.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::xunlei


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ xunlei-uos ];

}



