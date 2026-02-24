# @path: ~/projects/configs/nix-config/nixos/core/srv/hardware/firmware.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::hardware::firmware


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  services = {
    # Firmware update and power manager
    fwupd.enable = true;
  };


}


