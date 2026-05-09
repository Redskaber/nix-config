# @path: ~/projects/configs/nix-config/tests/nixos/core/base/boot.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::base::boot
# @source: nixos/core/base/boot.nix
#
# Verifies the NixOS boot subsystem:
#   - Reaches multi-user.target
#   - PID 1 is systemd
#   - system-running state is "running" or "degraded"
#   - kernel version non-empty

{ pkgs, lib, ... }:
{
  name = "nixos_core_base_boot";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
  };

  testScript = ''
    start_all()

    with subtest("boot: reaches multi-user.target"):
        machine.wait_for_unit("multi-user.target")
        machine.screenshot("boot_ok")

    with subtest("boot: system state is running or degraded"):
        out = machine.succeed("systemctl is-system-running || true").strip()
        print(f"system state: {out}")
        assert out in {"running", "degraded"}, f"Unexpected state: {out}"

    with subtest("boot: PID 1 is systemd"):
        exe = machine.succeed("readlink /proc/1/exe").strip()
        print(f"/proc/1/exe -> {exe}")
        assert "systemd" in exe, f"PID 1 is not systemd: {exe}"

    with subtest("boot: kernel version non-empty"):
        kver = machine.succeed("uname -r").strip()
        print(f"kernel: {kver}")
        assert kver != "", "Empty kernel version"
  '';
}
