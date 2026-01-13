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
    # Configure network connections interactively with nmcli or nmtui.
    networkmanager.enable = true;
    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable firewall
    # networking.firewall.allowedTCPPorts = [ ... ];
    # networking.firewall.allowedUDPPorts = [ ... ];
    # Or disable the firewall altogether.
    firewall.enable = true;
  };
}

