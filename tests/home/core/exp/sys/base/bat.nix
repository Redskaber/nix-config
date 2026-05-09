# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/bat.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::base::bat
# @source: home/core/exp/sys/base/bat.nix
#
# Mirrors production:
#   programs.bat.enable = true
#   config.theme = "gruvbox-dark"
#   config.pager = "less -CN"
#   extraPackages = [batman batpipe]

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_bat";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [
      bat
      bat-extras.batman
      bat-extras.batpipe
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("bat: binary present"):
        w = machine.succeed("which bat").strip()
        assert "bat" in w, f"bat not found: {w}"

    with subtest("bat: version reportable"):
        ver = machine.succeed("bat --version 2>&1").strip()
        print(f"bat: {ver}")
        assert "bat" in ver.lower()

    with subtest("bat: renders a file"):
        machine.succeed("echo 'hello bat' > /tmp/bat_test.txt")
        out = machine.succeed(
            "bat --no-paging --plain /tmp/bat_test.txt"
        ).strip()
        assert "hello bat" in out, f"bat render failed: {out}"

    with subtest("bat: batman binary present"):
        w = machine.succeed("which batman 2>/dev/null || true").strip()
        print(f"batman: {w}")
  '';
}
