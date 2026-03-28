# @path: ~/projects/configs/nix-config/nixos/core/base/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::base::default


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    ./bluetooth.nix
    ./boot.nix
    ./hardware.nix
    ./i18n.nix
    ./memory.nix
    ./network.nix
    ./nix.nix
    ./portal.nix
    ./sound.nix
    ./systemd.nix
    ./user.nix
    ./virtual.nix
  ];


}


