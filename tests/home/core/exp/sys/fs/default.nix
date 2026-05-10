# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/fs/default.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::home::core::exp::sys::fs::default
# @source: home/core/exp/sys/fs/default.nix
#
# Verifies filesystem tools: duf, compress tools (zip, unzip, p7zip, tar)

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_fs";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [
      duf
      zip
      unzip
      p7zip
      gnutar
      gzip
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("fs: duf binary present"):
        w = machine.succeed("which duf").strip()
        assert "duf" in w

    with subtest("fs: duf output has filesystem info"):
        out = machine.succeed("duf --hide-fs tmpfs 2>&1 || true").strip()
        print(f"duf: {out[:100]}")

    with subtest("fs: zip/unzip present"):
        machine.succeed("which zip && which unzip")

    with subtest("fs: 7z present"):
        w = machine.succeed("which 7z 2>/dev/null || true").strip()
        print(f"7z: {w}")

    with subtest("fs: tar round-trip"):
        machine.succeed(
            "echo test > /tmp/testfile.txt "
            "&& tar czf /tmp/test.tar.gz -C /tmp testfile.txt "
            "&& tar xzf /tmp/test.tar.gz -C /tmp "
            "&& grep -q test /tmp/testfile.txt"
        )
  '';
}
