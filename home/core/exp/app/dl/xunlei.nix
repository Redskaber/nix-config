# @path: ~/projects/configs/nix-config/home/core/exp/app/dl/xunlei.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::dl::xunlei


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



