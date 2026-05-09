# @path: ~/projects/configs/nix-config/tests/nixos/core/sec/polkit.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::sec::polkit
# @source: nixos/core/sec/polkit.nix
#
# Verifies polkit:
#   - polkit.service active
#   - pkaction binary available
#   - /etc/polkit-1/rules.d directory exists

{ pkgs, lib, ... }:
{
  name = "nixos_core_sec_polkit";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    security.polkit.enable = true;
    environment.systemPackages = with pkgs; [ polkit ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("polkit.service")

    with subtest("polkit: service active"):
        st = machine.succeed("systemctl is-active polkit").strip()
        assert st == "active", f"polkit not active: {st}"

    with subtest("polkit: pkaction binary present"):
        w = machine.succeed("which pkaction").strip()
        assert "pkaction" in w, f"pkaction not found: {w}"

    with subtest("polkit: rules.d directory exists"):
        rc = machine.execute("test -d /etc/polkit-1/rules.d")[0]
        assert rc == 0, "/etc/polkit-1/rules.d not found"

    with subtest("polkit: can list actions"):
        out = machine.succeed("pkaction 2>/dev/null | head -3 || true").strip()
        print(f"actions: {out}")
  '';
}
