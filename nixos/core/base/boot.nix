
# @path: ~/projects/configs/nix-config/nixos/core/base/boot.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::base::boot


{ inputs
, shared
, config
, lib
, pkgs
, modulesPath
, ...
}:
{
  # Bootloader
  boot = {
    consoleLogLevel = 3;

    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.enable = true;
    loader.timeout = 5;
    initrd = {
      enable = true;
      verbose = false;
      systemd.enable = true;
    };

    # This is for OBS Virtual Cam Support
    #kernelModules = [ "v4l2loopback" ];
    #  extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "systemd.mask=systemd-vconsole-setup.service"
      "systemd.mask=dev-tpmrm0.device"    # this is to mask that stupid 1.5 mins systemd bug
      "nowatchdog"
      "modprobe.blacklist=sp5100_tco"     # watchdog for AMD
      "modprobe.blacklist=iTCO_wdt"       # watchdog for Intel
    ];
    supportedFilesystems = [ "ntfs" ];

    # Needed For Some Steam Games
    #kernel.sysctl = {
    #  "vm.max_map_count" = 2147483642;
    #};
    # Make /tmp a tmpfs
    tmp = {
      useTmpfs = false;
      tmpfsSize = "30%";
    };
    # Appimage Support
    binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
      magicOrExtension = ''\x7fELF....AI\x02'';
    };
    plymouth.enable = true;
  };


}


