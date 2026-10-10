# @path: ~/projects/configs/nix-config/platform/nixos/core/drive/nvidia-prime.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::drive::nvidia-prime

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics.extraPackages = with pkgs; [
    nvidia-vaapi-driver
  ];

  hardware.nvidia = {
    # enabled = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    nvidiaSettings = true;
    videoAcceleration = true;
    open = false;

    prime = {
      # Bus IDs are machine fingerprints — they live in
      # hosts/<hostName>/default.nix (host layer owns hardware identity).

      offload = {
        enable = true;
        enableOffloadCmd = true;
        offloadCmdMainProgram = "nvidia-offload";
      };
    };

    powerManagement.enable = false;
    powerManagement.finegrained = false;
  };

  boot.blacklistedKernelModules = [ "nouveau" ];

}
