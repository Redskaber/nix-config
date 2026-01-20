# @path: ~/projects/configs/nix-config/home/core/app/baidupcs-go.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::app:baidupcs-go
# - baidu-networkdisk


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ baidupcs-go ];

}


