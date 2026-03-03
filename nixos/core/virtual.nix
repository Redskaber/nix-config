# @path: ~/projects/configs/nix-config/nixos/core/virtual.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::virtual


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  # Add user to libvirtd incus-admin waydroid group
  users.users.kilig.extraGroups = [ "libvirtd" "incus-admin" "waydroid" ];

  ## For AMD CPU, add "kvm-amd" to kernelModules.
  # boot.kernelModules = ["kvm-amd"];
  # boot.extraModprobeConfig = "options kvm_amd nested=1";  # for amd cpu
  #
  ## For Intel CPU, add "kvm-intel" to kernelModules.
  # boot.kernelModules = ["kvm-intel"];
  # boot.extraModprobeConfig = "options kvm_intel nested=1"; # for intel cpu

  # GPU through
  boot.kernelModules = [ "vfio-pci" ];

  # services.flatpak.enable = true;

  # Install necessary packages
  environment.systemPackages = with pkgs; [
    # 虚拟机管理工具
    virt-manager
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    virtio-win
    win-spice

    # 容器工具
    podman-compose
    buildah
    skopeo

    # QEMU全架构支持
    qemu_kvm  # 主要架构支持
    qemu      # 其他架构支持

    #Incus
    zfs
  ];

  # Manage the virtualisation services
  virtualisation = {
    # KVM/QEMU
    libvirtd = {
      enable = true;
      package = pkgs.libvirt;
      sshProxy = true;
      qemu = {
        package = pkgs.qemu;
        swtpm.enable = true;  # 安全启动支持
        runAsRoot = false;    # 安全最佳实践
        vhostUserPackages = [ pkgs.virtiofsd ];  # 高性能共享文件系统
      };
      nss = {
        enable = true;      # 网络服务切换
        enableGuest = false;
      };
      # 允许使用网桥
      allowedBridges = [ "virbr0" ];
      # 开启libvirt防火墙规则
      firewallBackend = "nftables";
      startDelay = 0;
      shutdownTimeout = 300;
      onBoot = "start";      # 系统启动时不自动启动VM
      onShutdown = "suspend";
      extraOptions = [ ];
      extraConfig = "";
    };

    # Podman - 应用容器
    podman = {
      enable = true;
      dockerCompat = true;  # 提供docker CLI兼容
      defaultNetwork.settings.dns_enabled = true;  # 容器间DNS解析
      # 自动清理资源
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };
      # 网络套接字配置
      # networkSocket = {
      #   enable = true;
      #   server = "ghostunnel";
      #   listenAddress = "127.0.0.1";
      #   port = "2375";
      #   # 在开发环境中可开启，生产环境应禁用
      #   openFirewall = false;
      # };
    };

    # OCI容器后端
    oci-containers = {
      backend = "podman";
      containers = {
        # 示例容器配置
        # nginx = {
        #   image = "nginx:latest";
        #   ports = [ "8080:80" ];
        #   autoStart = true;
        # };
      };
    };

    # Incus - 系统容器
    incus = {
      enable = true;
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
        };
        storage_pools = [
          {
            name = "default";
            driver = "zfs";  # or dir
            config.source = "/var/lib/incus";
          }
        ];
        networks = [
          {
            name = "lxdbr0";
            type = "bridge";
            config = {
              "ipv4.address" = "10.0.3.1/24";
              "ipv4.nat" = "true";
              "ipv6.address" = "fd42::1/64";
              "ipv6.nat" = "true";
            };
          }
        ];
      };
      ui = {
        enable = true;  # Web管理界面
        package = pkgs.incus-ui-canonical;
      };
    };

    # Waydroid - Android应用
    waydroid = {
      enable = true;
    };

    # 容器策略
    containers = {
      enable = true;
      # 设置容器存储
      storage.settings = {
        driver = "btrfs";
        root = "/var/lib/containers/storage";
      };
      # 配置容器镜像源
      registries.search = [ "docker.io" "ghcr.io" "quay.io" ];
    };

    # 辅助功能
    spiceUSBRedirection.enable = true;  # USB设备重定向
  };

  services.spice-vdagentd.enable = true; # 剪贴板/分辨率共享
  programs.virt-manager = {   # libvirt图形管理
    enable = true;
    package = pkgs.virt-manager;
  };
  programs.adb.enable = true;  # Android调试桥


  # 网络配置 - 支持虚拟化网络
  networking = {
    # Incus need
    nftables.enable = true;
    # 配置防火墙规则
    firewall = {
      enable = true;
      # 允许libvirt和容器网络
      allowedUDPPorts = [ 53 67 547 5353 ];
      allowedTCPPorts = [ 53 68 546 5353 8443 ];   # Incus UI: 8443
    };
  };


  # Waydroid特定配置 (当启用时)
  environment.etc."waydroid/waydroid.cfg".text =
    if config.virtualisation.waydroid.enable then ''
      [properties]
      persist.waydroid.width = 1280
      persist.waydroid.height = 720
      persist.waydroid.dummy_fps = 60
      persist.waydroid.multi_windows = true
    '' else "";


}


