# @path: ~/projects/configs/nix-config/platform/nixos/core/base/memory.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::core::base::memory

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
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
