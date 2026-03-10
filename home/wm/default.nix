# @path: ~/projects/configs/nix-config/home/wm/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::wm::default



{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [ ./${shared.window-manager.value} ];


}


