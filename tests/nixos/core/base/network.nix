# @path: ~/projects/configs/nix-config/tests/nixos/core/base/network.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::base::network
# @source: nixos/core/base/network.nix
#
# Mirrors production config:
#   networking.hostName = shared.hostName  ("nixos")
#   networkmanager.enable = true
#   enableIPv6 = true
#   firewall.enable = true
#   firewall.allowedTCPPorts = [22 80 443]

{ pkgs, lib, ... }:
{
  name = "nixos_core_base_network";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 512;

    networking = {
      hostName = "nixos";
      networkmanager.enable = true;
      enableIPv6 = true;
      firewall = {
        enable          = true;
        allowedTCPPorts = [ 22 80 443 ];
        allowedUDPPorts = [];
      };
    };

    environment.systemPackages = with pkgs; [ iproute2 ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("network: hostname is nixos"):
        hn = machine.succeed("hostname").strip()
        assert hn == "nixos", f"Expected 'nixos', got '{hn}'"

    with subtest("network: NetworkManager active"):
        machine.wait_for_unit("NetworkManager.service")
        st = machine.succeed("systemctl is-active NetworkManager").strip()
        assert st == "active", f"NM not active: {st}"

    with subtest("network: firewall active"):
        machine.wait_for_unit("firewall.service")
        st = machine.succeed("systemctl is-active firewall").strip()
        assert st == "active", f"firewall not active: {st}"

    with subtest("network: loopback UP"):
        lo = machine.succeed("ip link show lo").strip()
        assert "UP" in lo, f"lo not UP: {lo}"

    with subtest("network: IPv6 not disabled"):
        val = machine.succeed(
            "cat /proc/sys/net/ipv6/conf/all/disable_ipv6"
        ).strip()
        assert val == "0", f"IPv6 disabled (expected 0, got {val})"
  '';
}
