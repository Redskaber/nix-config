# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/fd.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::base::fd
# @source: home/core/exp/sys/base/fd.nix

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_fd";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ fd ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("fd: binary present"):
        w = machine.succeed("which fd").strip()
        assert "fd" in w, f"fd not found: {w}"

    with subtest("fd: version reportable"):
        ver = machine.succeed("fd --version 2>&1").strip()
        print(f"fd: {ver}")
        assert "fd" in ver.lower()

    with subtest("fd: finds files by pattern"):
        machine.succeed("mkdir -p /tmp/fd_test && touch /tmp/fd_test/hello.txt")
        out = machine.succeed("fd hello /tmp/fd_test").strip()
        assert "hello.txt" in out, f"fd search failed: {out}"
  '';
}
