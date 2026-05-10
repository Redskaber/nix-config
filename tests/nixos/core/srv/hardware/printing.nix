# @path: ~/projects/configs/nix-config/tests/nixos/core/srv/hardware/printing.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::nixos::core::srv::hardware::printing
# @source: nixos/core/srv/hardware/printing.nix
#
# Verifies CUPS printing stack:
#   - cups service active
#   - lpstat binary present
#   - localhost:631 (CUPS web UI) accessible

{ pkgs, lib, ... }:
{
  name = "nixos_core_srv_hardware_printing";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 512;

    services.printing = {
      enable = true;
      startWhenNeeded = false;
    };

    environment.systemPackages = with pkgs; [ cups ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("cups.service")

    with subtest("printing: cups service active"):
        st = machine.succeed("systemctl is-active cups.service").strip()
        assert st == "active", f"cups not active: {st}"

    with subtest("printing: lpstat binary present"):
        w = machine.succeed("which lpstat 2>/dev/null || true").strip()
        print(f"lpstat: {w}")
        assert "lpstat" in w, f"lpstat not found: {w}"

    with subtest("printing: CUPS socket listening on 631"):
        machine.wait_for_open_port(631)
        rc = machine.execute("curl -sf http://localhost:631/ -o /dev/null")[0]
        print(f"CUPS http rc: {rc}")
  '';
}
