# @path: ~/projects/configs/nix-config/platform/nixos/dm/gdm/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::dm::gdm::default

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{

  services.displayManager = {
    enable = true;
    gdm = {
      enable = true;
      debug = false;
      wayland = true;
      autoSuspend = true;
      autoLogin.delay = 0;
    };
  };

}
