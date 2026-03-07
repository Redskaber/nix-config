# @path: ~/projects/configs/nix-config/nixos/core/sec/pam.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::sec::pam


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


