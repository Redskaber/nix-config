# @path: ~/projects/configs/nix-config/nixos/core/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::default


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    ./drive
    ./security
    ./srv

    ./bluetooth.nix
    ./boot.nix
    ./compat.nix
    ./hardware.nix
    ./i18n.nix
    ./memory.nix
    ./network.nix
    ./nix.nix
    ./obs.nix
    ./portal.nix
    ./sound.nix
    ./steam.nix
    ./systemd.nix
    ./user.nix
    ./virtual.nix
  ];


}


