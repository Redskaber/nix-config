# @path: ~/projects/configs/nix-config/home/core/exp/app/img/imv.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::img::imv
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


