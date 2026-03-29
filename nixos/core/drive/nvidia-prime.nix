# @path: ~/projects/configs/nix-config/nixos/core/drive/nvidia-prime.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::drive::nvidia-prime


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  services.xserver.videoDrivers = ["nvidia"];

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
      # TODO: AUTO-READ-USER INFO
      intelBusId = "PCI:0:2:0";  # 00:02.0
      nvidiaBusId = "PCI:6:0:0"; # 06:00.0

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


