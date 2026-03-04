# @path: ~/projects/configs/nix-config/nixos/core/security/pam.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::security::pam


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  security.pam.services.swaylock = {
    text = ''
      auth include login
    '';
  };


}


