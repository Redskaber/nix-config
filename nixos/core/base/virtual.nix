# @path: ~/projects/configs/nix-config/nixos/core/base/virtual.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::base::virtual
#
# - echo "fd42:$(openssl rand -hex 2):$(openssl rand -hex 2):$(openssl rand -hex 2):$(openssl rand -hex 2)::1/64"
#   fd42:8bdd:fa83:9703:95b2::1/64
#
# ## v26.05
# Failed assertions:
# - The option definition `programs.adb' in `/nix/store/b3qxh150g0ni445dyx40c249xmjyr230-source/nixos/core/base/virtual.nix' no longer has any effect; please remove it.
# This option is no longer needed as systemd 258 handles uaccess rules automatically. Please add `pkgs.android-tools` to your system packages to get the adb command.


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
shared.version.value.adb // {
  # Add user to libvirtd incus-admin waydroid group
  # NOTE: These groups are created by their respective virtualisation services.
  #       They are safe to declare here because the services are enabled below.
  users.users.${shared.user.username}.extraGroups = [ "libvirtd" "incus-admin" "waydroid" ];

  ## For AMD CPU, add "kvm-amd" to kernelModules.
  # boot.kernelModules = ["kvm-amd"];
  # boot.extraModprobeConfig = "options kvm_amd nested=1";  # for amd cpu
  #
  ## For Intel CPU, add "kvm-intel" to kernelModules.
  # boot.kernelModules = ["kvm-intel"];
  # boot.extraModprobeConfig = "options kvm_intel nested=1"; # for intel cpu

  # GPU through
  boot.kernelModules =
    lib.optional (builtins.elem "nvidia-prime" shared.drive.value) "vfio-pci";

  # zfs sup
  # generate hostId（terminal exec-once）：
  #   $ head -c4 /dev/urandom | od -A none -t x4
  #   output-example：a3f9c1e7
  # networking.hostId = "372d3766";
  # boot.supportedFilesystems = [ "zfs" ];

  # services.flatpak.enable = true;

  # Install necessary packages
  environment.systemPackages = with pkgs; [
    # VM management tools
    virt-manager
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    virtio-win
    win-spice

    # container tools
    podman-compose
    buildah
    skopeo

    # QEMUall-arch support
    qemu_kvm # architecturesupport
    qemu # architecturesupport

    #Incus
    # zfs

    # v26.05
    android-tools   # programs.adb remove
  ];

  # Manage the virtualisation services
  virtualisation = {
    # KVM/QEMU
    libvirtd = {
      enable = shared.services.virt.libvirtd.install;
      package = pkgs.libvirt;
      sshProxy = true;
      qemu = {
        package = pkgs.qemu;
        swtpm.enable = true; # secure boot support
        runAsRoot = false; # secure
        vhostUserPackages = [ pkgs.virtiofsd]; # filesystem
      };
      nss = {
        enable = true; # network service switch
        enableGuest = false;
      };
      # allow bridge usage
      allowedBridges = [ "virbr0" ];
      # libvirt
      firewallBackend = "nftables";
      startDelay = 0;
      shutdownTimeout = 300;
      onBoot = "start"; # systemstart autostartVM
      onShutdown = "suspend";
      extraOptions = [ ];
      extraConfig = "";
    };

    # Podman - app containers
    podman = {
      enable = shared.services.virt.podman.install;
      dockerCompat = true; # docker CLIcompatible
      defaultNetwork.settings.dns_enabled = true; # DNS
      # auto cleanup
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };
      # network socket config
      # networkSocket = {
      #   enable = true;
      #   server = "ghostunnel";
      #   listenAddress = "127.0.0.1";
      #   port = "2375";
      # # indev environmentin，production environmentdisable
      #   openFirewall = false;
      # };
    };

    # OCIafter
    oci-containers = {
      backend = "podman";
      containers = {
        # exampleconfig
        # nginx = {
        #   image = "nginx:latest";
        #   ports = [ "8080:80" ];
        #   autoStart = true;
        # };
      };
    };

    # Incus - system containers
    incus = {
      enable = shared.services.virt.incus.install;
      package = pkgs.incus;
      lxcPackage = config.virtualisation.lxc.package;
      clientPackage = config.virtualisation.incus.package.client;
      agent.enable = false;
      startTimeout = 600;
      softDaemonRestart = true;
      socketActivation = false;
      preseed = {
        config = {
          "core.https_address" = "[::]:8443";
          "core.trust_ca_certificates" = "false";   # 不自动信任CA签名的客户端
          "images.auto_update_cached" = "true";
          "images.auto_update_interval" = "168";    # 每24*7小时检查更新
          "images.remote_cache_expiry" = "10";      # 10天后清理未使用缓存
          "instances.nic.host_name" = "random";     # 随机生成主机接口名
        };
        storage_pools = [
          {
            name = "default";
            driver = "dir";  # zfs
            config = {
              source = "/var/lib/incus/storage-pools/default";
            };
          }
        ];
        networks = [
          {
            name = "incus-br0";
            type = "bridge";
            config = {
              "ipv4.address" = "10.217.144.1/24";
              "ipv4.nat" = "true";
              "ipv6.address" = shared.network.incusIPv6;
              "ipv6.nat" = "true";
              "dns.domain" = "incus";
              "dns.mode" = "managed";
            };
          }
        ];
        profiles = [
          {
            name = "default";
            devices = {
              # 
              root = {
                type = "disk";
                pool = "default"; # mustname
                path = "/";
              };
              # 
              eth0 = {
                type = "nic";
                nictype = "bridged";
                parent = "incus-br0"; # mustname
                name = "eth0";
              };
            };
          }
        ];
      };
      ui = {
        enable = true; # Webmanaged
        package = pkgs.incus-ui-canonical;
      };
    };

    # Waydroid - Android
    waydroid = {
      enable = shared.services.virt.waydroid.install;
    };

    # 容器策略
    containers = {
      enable = true;
      # setting
      storage.settings = {
        driver = "btrfs";
        root = "/var/lib/containers/storage";
      };
      # config
      registries.search = [ "docker.io" "ghcr.io" "quay.io" ];
    };

    # auxiliary features
    spiceUSBRedirection.enable = true; # USBdevice redirection
  };

  services.spice-vdagentd.enable = true; # clipboard/resolution sharing
  programs.virt-manager = { # libvirtGUI management
    enable = true;
    package = pkgs.virt-manager;
  };


  # config - support
  networking = {
    # Incus need
    nftables.enable = true;
    # config
    firewall = {
      enable = true;
      # libvirtand
      allowedUDPPorts = [ 53 67 547 5353 ];
      allowedTCPPorts = [ 53 68 546 5353 8443 ];   # Incus UI: 8443
    };
  };


  # Waydroidconfig (whenenable)
  environment.etc."waydroid/waydroid.cfg".text =
    if config.virtualisation.waydroid.enable then ''
      [properties]
      persist.waydroid.width = 1280
      persist.waydroid.height = 720
      persist.waydroid.dummy_fps = 60
      persist.waydroid.multi_windows = true
    '' else "";

  # Virtualization service autostart control (install but not autostart = clear wantedBy)
  systemd.services.libvirtd.wantedBy =
    lib.mkForce (lib.optional shared.services.virt.libvirtd.autostart "multi-user.target");
  systemd.services.incusd.wantedBy =
    lib.mkForce (lib.optional shared.services.virt.incus.autostart "multi-user.target");
  systemd.services.waydroid-container.wantedBy =
    lib.mkForce (lib.optional shared.services.virt.waydroid.autostart "multi-user.target");
  systemd.services.podman.wantedBy =
    lib.mkForce (lib.optional shared.services.virt.podman.autostart "multi-user.target");

}
