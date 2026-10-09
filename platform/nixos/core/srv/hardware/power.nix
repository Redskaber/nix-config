# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/hardware/power.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::core::srv::hardware::power

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
    upower.enable = true;
  };

}
