# @path: ~/projects/configs/nix-config/home/core/app/img/imv.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::img::imv
# - image viewer


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [ imv ];

}


