# @path: ~/projects/configs/nix-config/nixos/core/network.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::network


{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  networking = {
    # TODO: Set your hostname
    hostName = "nixos";

    # Use: 'nmcli' or 'nmtui'
    networkmanager.enable = true;
    wireless.enable = false;

    # enableIPv6 = false;
    # allowPing = true;
    # logRefusedConnections = false;

    nameservers = [
      "1.1.1.1"               # Cloudflare
      "8.8.8.8"               # Google(main)
      "8.8.4.4"               # Google(other)
      "2606:4700:4700::1111"  # Cloudflare IPv6
    ];

    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable firewall
    # networking.firewall.allowedTCPPorts = [ ... ];
    # networking.firewall.allowedUDPPorts = [ ... ];
    # Or disable the firewall altogether.
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
      allowedUDPPorts = [];
    };

  };

  environment.systemPackages = with pkgs; [ networkmanagerapplet ];
}

