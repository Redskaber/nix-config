# @path: ~/projects/configs/nix-config/platform/nixos/core/sec/pam.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::core::sec::pam

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  security.pam.services.swaylock = {
    text = ''
      auth include login
    '';
  };

}
