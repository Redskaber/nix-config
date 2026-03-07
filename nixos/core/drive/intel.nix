# @path: ~/projects/configs/nix-config/nixos/core/drive/intel.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::drive::intel


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
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


