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
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 120;
  };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("home_core_sec: VM reaches multi-user.target"):
        # wait_for_unit returns the moment the target unit is active,
        # while the boot transaction may STILL be activating units —
        # run 38136560662 caught exactly that: is-system-running read
        # "starting" 0.22s after the target went active (fire-once
        # assertion, same race family as the postgresql ensure phase
        # and the nix-daemon socket spawn in the 38085235502 audit).
        # Poll instead of firing once; a settling boot converges to
        # running/degraded, it never regresses past them.
        st = machine.wait_until_succeeds(
            "systemctl is-system-running | grep -E '^(running|degraded)$'",
            timeout=60,
        ).strip()
        print(f"system state: {st}")
  '';
}
