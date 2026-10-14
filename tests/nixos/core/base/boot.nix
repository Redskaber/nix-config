# @path: ~/projects/configs/nix-config/tests/nixos/core/base/boot.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::base::boot
# @source: platform/nixos/system/core/base/boot.nix
#
# Verifies the NixOS boot subsystem:
#   - Reaches multi-user.target
#   - PID 1 is systemd
#   - system-running state is "running" or "degraded"
#   - kernel version non-empty

{ pkgs, lib, ... }:
{
  name = "nixos_core_base_boot";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 120;
  };

  nodes.machine = {
    virtualisation.memorySize = 512;
  };

  testScript = ''
    start_all()

    with subtest("boot: reaches multi-user.target"):
        machine.wait_for_unit("multi-user.target")
        machine.screenshot("boot_ok")

    with subtest("boot: system state is running or degraded"):
        # Defense in depth for the fire-once race caught in run
        # 38136560662 (home_core_sec): wait_for_unit returns while the
        # boot transaction is still settling, so is-system-running can
        # transiently read "starting" on a loaded runner. Poll until
        # the state converges to running/degraded — it never regresses
        # past them once reached.
        out = machine.wait_until_succeeds(
            "systemctl is-system-running | grep -E '^(running|degraded)$'",
            timeout=60,
        ).strip()
        print(f"system state: {out}")

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
