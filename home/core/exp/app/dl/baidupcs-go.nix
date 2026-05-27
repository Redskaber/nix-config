# @path: ~/projects/configs/nix-config/home/core/exp/app/dl/baidupcs-go.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::dl::baidupcs-go
# - baidu-networkdisk => upkgs


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ baidupcs-go ];

}


