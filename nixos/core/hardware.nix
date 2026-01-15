# @path: ~/projects/configs/nix-config/nixos/core/hardware.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::hardware


{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  # FIXME: temp used driver mod config
  hardware = {
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver    # Gen8+
        (intel-vaapi-driver.override { enableHybridCodec = true; })
        libva-utils           # (debug) vainfo
        libva-vdpau-driver    # (vaapiVdpau) Firefox/Chromium
        libvdpau-va-gl
        libva
      ];
    };

    enableRedistributableFirmware = true;     # (Wi-Fi/核显微码)
    cpu.intel.updateMicrocode = true;         # Intel CPU 微码(remaind)
  };
}


