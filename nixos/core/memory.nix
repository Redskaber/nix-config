# @path: ~/projects/configs/nix-config/nixos/core/memory.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::memory


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  # zram
  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 30;
    swapDevices = 1;
    algorithm = "zstd";
  };

  # battery
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil";
  };

}



