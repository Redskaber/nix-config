# @path: ~/projects/configs/nix-config/nixos/core/boot.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::boot


{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  # Bootloader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    loader.timeout = 2;

    initrd.enable = true;
    initrd.verbose = false;
    initrd.systemd.enable = true;

    consoleLogLevel = 3;
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = [ "ntfs" ];

  };
}

