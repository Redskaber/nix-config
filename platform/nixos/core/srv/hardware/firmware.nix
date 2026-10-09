# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/hardware/firmware.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::core::srv::hardware::firmware

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
    # Firmware update and power manager
    fwupd.enable = true;
  };

}
