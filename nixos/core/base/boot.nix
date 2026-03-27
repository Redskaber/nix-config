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
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];


  # FIXME: Repalce your fileSystems
  # through: 'nixos-generate-config --root /mnt' &&
  # Copy your hardware-configuration.nix: "fileSystems.xxx and swapDevices" configs
  # Repalce start line
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/c2624c51-329a-4f2b-acc2-c829d6f3e324";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/974A-6A53";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  fileSystems."/var/lib/lxcfs" =
    { device = "lxcfs";
      fsType = "fuse.lxcfs";
    };

  fileSystems."/var/lib/incus/devices" =
    { device = "tmpfs";
      fsType = "tmpfs";
    };

  fileSystems."/var/lib/incus/shmounts" =
    { device = "tmpfs";
      fsType = "tmpfs";
    };

  fileSystems."/var/lib/incus/guestapi" =
    { device = "tmpfs";
      fsType = "tmpfs";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/50edded4-41e4-4f7e-8e97-fd803b1eb420"; }
    ];
  # Repalce end line


  # Bootloader
  boot = {
    consoleLogLevel = 3;

    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.enable = true;
    loader.timeout = 5;

    initrd = {
      enable = true;
      verbose = false;
      kernelModules = [ ];
      # FIXME: Replace your availableKernelModules
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
      systemd.enable = true;
    };

    # FIXME: Replace your kernelModules
    kernelModules = [
      "kvm-intel"         # intel
      "v4l2loopback"      # OBS Virtual Cam
    ];
    kernelPackages = pkgs.linuxPackages_latest;
    # FIXME: Replace your kernelParams
    kernelParams = [
      "systemd.mask=systemd-vconsole-setup.service"
      "systemd.mask=dev-tpmrm0.device"    # this is to mask that stupid 1.5 mins systemd bug
      "nowatchdog"
      "modprobe.blacklist=sp5100_tco"     # watchdog for AMD
      "modprobe.blacklist=iTCO_wdt"       # watchdog for Intel
    ];
    extraModulePackages = [
      config.boot.kernelPackages.v4l2loopback   # OBS Virtual Cam
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


  nixpkgs.hostPlatform = lib.mkDefault shared.arch.tag;
  # FIXME: intel Exclusive
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

}


