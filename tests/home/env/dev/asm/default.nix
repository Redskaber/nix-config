# @path: ~/projects/configs/nix-config/tests/home/env/dev/asm/default.nix
# @author: redskaber
# @datetime: 2026-10-30
# @description: tests::home::env::dev::asm::default
# @source: home/env/dev/asm/default.nix
#
# Mirrors production buildInputs for the assembly devenv:
#   nasm, nasmfmt, binutils (ld/objdump), gdb, pkg-config, gnumake

{ pkgs, lib, ... }:
{
  name = "home_env_dev_asm_default";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 120;
  };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [
      nasm
      nasmfmt
      binutils
      gdb
      gnumake
      pkg-config
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("asm_dev: nasm binary present"):
        ver = machine.succeed("nasm -v 2>&1").strip()
        print(f"nasm: {ver}")
        assert "NASM" in ver, f"nasm not found: {ver}"

    with subtest("asm_dev: ld binary present"):
        ver = machine.succeed("ld -v 2>&1").strip()
        print(f"ld: {ver}")
        assert "GNU" in ver or "ld" in ver.lower(), f"ld not found: {ver}"

    with subtest("asm_dev: objdump binary present"):
        ver = machine.succeed("objdump --version 2>&1 | head -1").strip()
        print(f"objdump: {ver}")
        assert "objdump" in ver.lower(), f"objdump not found: {ver}"

    with subtest("asm_dev: gdb binary present"):
        ver = machine.succeed("gdb --version 2>&1 | head -1").strip()
        print(f"gdb: {ver}")
        assert "gdb" in ver.lower(), f"gdb not found: {ver}"

    with subtest("asm_dev: nasmfmt binary present"):
        w = machine.succeed("which nasmfmt 2>/dev/null || true").strip()
        print(f"nasmfmt: {w}")

    with subtest("asm_dev: assemble, link and run hello-world"):
        machine.succeed(r"""
          set -e
          cat > /tmp/hello.asm << 'AEOF'
          global _start
          section .text
          _start:
              mov rax, 1
              mov rdi, 1
              mov rsi, msg
              mov rdx, len
              syscall
              mov rax, 60
              xor rdi, rdi
              syscall
          section .data
          msg: db "asm_hello_ok", 10
          len: equ $ - msg
          AEOF
          nasm -f elf64 -o /tmp/hello.o /tmp/hello.asm
          ld -o /tmp/hello_asm /tmp/hello.o
          /tmp/hello_asm | grep -q 'asm_hello_ok'
        """)
  '';
}
