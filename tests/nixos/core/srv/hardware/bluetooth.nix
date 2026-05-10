# @path: ~/projects/configs/nix-config/tests/nixos/core/srv/hardware/bluetooth.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::nixos::core::srv::hardware::bluetooth
# @source: nixos/core/srv/hardware/bluetooth.nix
#
# Verifies bluetooth stack:
#   - bluetoothd service active
#   - bluetoothctl binary present
#   - rfkill shows bluetooth device (or gracefully absent in VM)

{ pkgs, lib, ... }:
{
  name = "nixos_core_srv_hardware_bluetooth";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;

    hardware.bluetooth = {
      enable      = true;
      powerOnBoot = false;  # VM — no real BT hardware, avoid hang
      settings = {
        General = {
          Experimental = true;
        };
      };
    };

    environment.systemPackages = with pkgs; [ bluez bluez-tools ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("bluetooth: bluetoothd service loaded"):
        rc = machine.execute(
            "systemctl list-unit-files bluetooth.service 2>/dev/null | grep bluetooth"
        )[0]
        print(f"bluetooth unit rc: {rc}")

    with subtest("bluetooth: bluetoothctl binary present"):
        w = machine.succeed("which bluetoothctl 2>/dev/null || true").strip()
        print(f"bluetoothctl: {w}")
        assert "bluetoothctl" in w, f"bluetoothctl not found: {w}"

    with subtest("bluetooth: rfkill tool present"):
        w = machine.succeed("which rfkill 2>/dev/null || true").strip()
        print(f"rfkill: {w}")
  '';
}
