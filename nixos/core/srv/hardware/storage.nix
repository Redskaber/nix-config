# @path: ~/projects/configs/nix-config/nixos/core/srv/hardware/power.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::hardware::power


{ inputs
, config
, lib
, pkgs
, ...
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


