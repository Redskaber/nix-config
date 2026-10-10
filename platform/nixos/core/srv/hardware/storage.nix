# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/hardware/storage.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::srv::hardware::power

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  services = {
    # No-server disable
    smartd = {
      enable = false;
      autodetect = true;
    };
    # SSD optimite
    fstrim = {
      enable = true;
      interval = "weekly";
    };
  };

}
