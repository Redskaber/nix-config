# @path: ~/projects/configs/nix-config/home/core/app/game/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::app::game::default



{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./minecraft.nix
  ];


}


