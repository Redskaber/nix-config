# @path: ~/projects/configs/nix-config/nixos/core/srv/security/keyring.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::security::keyring


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  services = {
    gnome.gnome-keyring.enable = true;
  };


}


