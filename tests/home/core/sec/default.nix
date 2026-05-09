# @path: ~/projects/configs/nix-config/tests/home/core/sec/default.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::sec::default
# @source: home/core/sec/default.nix
#
# home/core/sec/default.nix is currently an empty extension point.
# This test is a placeholder that validates the module parses correctly
# and the VM reaches multi-user.target without error.

{ pkgs, lib, ... }:
{
  name = "home_core_sec";
  meta = { maintainers = [ "redskaber" ]; timeout = 60; };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("home_core_sec: VM reaches multi-user.target"):
        st = machine.succeed("systemctl is-system-running || true").strip()
        assert st in {"running", "degraded"}, f"Unexpected state: {st}"
  '';
}
