# @path: ~/projects/configs/nix-config/platform/nixos/core/base/memory.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::base::memory

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
  # T7.1: bare-metal defaults — mkDefault, because specialized system
  # forms legitimately subtract them (the NixOS-WSL interpreter
  # plain-assigns powerManagement.enable = false: no batteries, no
  # suspend under the WSL kernel interface).
  powerManagement = {
    enable = lib.mkDefault true;
    cpuFreqGovernor = "schedutil";
  };

}
