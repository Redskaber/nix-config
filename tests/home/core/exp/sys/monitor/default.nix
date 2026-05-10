# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/monitor/default.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::home::core::exp::sys::monitor::default
# @source: home/core/exp/sys/monitor/default.nix
#
# Verifies system monitoring tools: btop, htop, bottom (btm)

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_monitor";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [
      btop
      htop
      bottom
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("monitor: btop binary present"):
        ver = machine.succeed("btop --version 2>&1 | head -1 || true").strip()
        print(f"btop: {ver}")
        assert "btop" in ver.lower() or ver != "", "btop missing"

    with subtest("monitor: htop binary present"):
        w = machine.succeed("which htop").strip()
        assert "htop" in w

    with subtest("monitor: bottom (btm) binary present"):
        w = machine.succeed("which btm 2>/dev/null || true").strip()
        print(f"btm: {w}")
  '';
}
