# @path: ~/projects/configs/nix-config/home/core/app/xunlei.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::xunlei


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [ xunlei-uos ];

}



