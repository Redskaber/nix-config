# @path: ~/projects/configs/nix-config/nixos/dm/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::dm::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./${shared.display-manager.tag}
  ];
}


