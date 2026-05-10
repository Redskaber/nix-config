# @path: ~/projects/configs/nix-config/tests/home/env/dev/c/default.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::home::env::dev::c::default
# @source: home/env/dev/c/default.nix
#
# Mirrors production buildInputs for C devenv:
#   gcc, gdb, clang-tools (clangd), cmake, gnumake, valgrind

{ pkgs, lib, ... }:
{
  name = "home_env_dev_c_default";
  meta = { maintainers = [ "redskaber" ]; timeout = 300; };

  nodes.machine = {
    virtualisation.memorySize = 768;
    environment.systemPackages = with pkgs; [
      gcc
      gdb
      clang-tools   # provides clangd
      cmake
      gnumake
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("c_dev: gcc binary present"):
        ver = machine.succeed("gcc --version 2>&1 | head -1").strip()
        print(f"gcc: {ver}")
        assert "gcc" in ver.lower(), f"gcc not found: {ver}"

    with subtest("c_dev: gdb binary present"):
        ver = machine.succeed("gdb --version 2>&1 | head -1").strip()
        print(f"gdb: {ver}")
        assert "gdb" in ver.lower(), f"gdb not found: {ver}"

    with subtest("c_dev: clangd binary present"):
        w = machine.succeed("which clangd").strip()
        assert "clangd" in w, f"clangd not found: {w}"

    with subtest("c_dev: cmake binary present"):
        ver = machine.succeed("cmake --version 2>&1 | head -1").strip()
        print(f"cmake: {ver}")
        assert "cmake" in ver.lower(), f"cmake not found: {ver}"

    with subtest("c_dev: make binary present"):
        ver = machine.succeed("make --version 2>&1 | head -1").strip()
        print(f"make: {ver}")
        assert "make" in ver.lower() or "GNU" in ver, f"make not found: {ver}"

    with subtest("c_dev: compile and run hello-world"):
        machine.succeed(r"""
          set -e
          cat > /tmp/hello.c << 'CEOF'
          #include <stdio.h>
          int main(void) { puts("c_hello_ok"); return 0; }
          CEOF
          gcc -o /tmp/hello_c /tmp/hello.c
          out=$(/tmp/hello_c)
          [ "$out" = "c_hello_ok" ] || { echo "Got: $out"; exit 1; }
        """)
  '';
}

