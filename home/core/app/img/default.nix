# @path: ~/projects/configs/nix-config/home/core/app/img/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::app::img::default



{ inputs
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./gimp.nix
    ./imagemagick.nix
    ./imv.nix
  ];


}


