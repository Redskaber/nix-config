# @path: ~/projects/configs/nix-config/nixos/core/drive/nvidia.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::drive::nvidia


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

    powerManagement.enable = false;
    powerManagement.finegrained = false;
  };

  boot.blacklistedKernelModules = [ "nouveau" ];

}


