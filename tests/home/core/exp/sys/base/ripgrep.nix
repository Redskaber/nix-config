# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/ripgrep.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::base::ripgrep
# @source: home/core/exp/sys/base/ripgrep.nix

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_ripgrep";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ ripgrep ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("ripgrep: binary present"):
        w = machine.succeed("which rg").strip()
        assert "rg" in w, f"rg not found: {w}"

    with subtest("ripgrep: version reportable"):
        ver = machine.succeed("rg --version 2>&1 | head -1").strip()
        print(f"rg: {ver}")
        assert "ripgrep" in ver.lower()

    with subtest("ripgrep: pattern search works"):
        machine.succeed("echo 'hello world' > /tmp/rg_test.txt")
        out = machine.succeed("rg 'hello' /tmp/rg_test.txt").strip()
        assert "hello" in out, f"rg search failed: {out}"
  '';
}
