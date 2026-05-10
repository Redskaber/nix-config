# @path: ~/projects/configs/nix-config/tests/home/env/dev/re/default.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::home::env::dev::re::default
# @source: home/env/dev/re/default.nix
#
# Reverse-engineering toolchain:
#   radare2, binutils (objdump, nm, readelf), strace, ltrace

{ pkgs, lib, ... }:
{
  name = "home_env_dev_re_default";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [
      radare2
      binutils
      strace
      ltrace
      file
      xxd
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("re_dev: radare2 binary present"):
        ver = machine.succeed("r2 -v 2>&1 | head -1").strip()
        print(f"r2: {ver}")
        assert "radare2" in ver.lower() or "r2" in ver.lower(), f"r2 not found: {ver}"

    with subtest("re_dev: objdump binary present"):
        ver = machine.succeed("objdump --version 2>&1 | head -1").strip()
        print(f"objdump: {ver}")
        assert "objdump" in ver.lower() or "GNU" in ver, f"objdump not found: {ver}"

    with subtest("re_dev: readelf present"):
        w = machine.succeed("which readelf").strip()
        assert "readelf" in w, f"readelf not found: {w}"

    with subtest("re_dev: strace present"):
        w = machine.succeed("which strace").strip()
        assert "strace" in w, f"strace not found: {w}"

    with subtest("re_dev: file utility present"):
        out = machine.succeed("file /bin/sh 2>&1").strip()
        print(f"file: {out}")
        assert "/bin/sh" in out, f"file utility broken: {out}"

    with subtest("re_dev: xxd hex dump works"):
        out = machine.succeed("echo 'AB' | xxd | head -1").strip()
        print(f"xxd: {out}")
        assert "41" in out or "4142" in out, f"xxd output unexpected: {out}"
  '';
}
