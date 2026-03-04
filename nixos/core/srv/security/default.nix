# @path: ~/projects/configs/nix-config/nixos/core/srv/security/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::security::default


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    ./keyring.nix
    ./ssh.nix
  ];


}


