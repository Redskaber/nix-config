# @path: ~/projects/configs/nix-config/nixos/core/security/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::security::default


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    ./secret

    ./pam.nix
    ./polkit.nix
  ];


}


