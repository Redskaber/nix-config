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
  hardware.graphics.extraPackages = with pkgs; [
    nvidia-vaapi-driver
  ];

  hardware.nvidia = {
    enabled = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    nvidiaSettings = true;
    videoAcceleration = true;
    open = true;

    prime = {
      intelBusId = "PCI:0@0:2:0";  # 00:02.0
      nvidiaBusId = "PCI:0@6:0:0"; # 06:00.0

      offload = {
        enable = true;
        enableOffloadCmd = true;
        offloadCmdMainProgram = "nvidia-offload";
      };

      # hardware.nvidia.powerManagement.enable = true;
      # hardware.nvidia.powerManagement.finegrained = true;
    };
  };

  services.xserver.videoDrivers = ["nvidia"];
  boot.blacklistedKernelModules = [ "nouveau" ];

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    NVIDIA_VISIBLE_DEVICES = "all";
    NVIDIA_DRIVER_CAPABILITIES = "all";
  };


}


