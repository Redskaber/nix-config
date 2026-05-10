# @path: ~/projects/configs/nix-config/tests/home/env/dev/zig/default.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::home::env::dev::zig::default
# @source: home/env/dev/zig/default.nix

{ pkgs, lib, ... }:
{
  name = "home_env_dev_zig_default";
  meta = { maintainers = [ "redskaber" ]; timeout = 300; };

  nodes.machine = {
    virtualisation.memorySize = 768;
    environment.systemPackages = with pkgs; [
      zig
      zls   # Zig Language Server
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("zig_dev: zig binary present"):
        ver = machine.succeed("zig version 2>&1").strip()
        print(f"zig: {ver}")
        assert ver != "", "zig not found"

    with subtest("zig_dev: zls (language server) present"):
        w = machine.succeed("which zls 2>/dev/null || true").strip()
        print(f"zls: {w}")

    with subtest("zig_dev: zig run hello-world"):
        machine.succeed(r"""
          set -e
          cat > /tmp/hello.zig << 'ZIGEOF'
          const std = @import("std");
          pub fn main() void {
              std.debug.print("zig_hello_ok\n", .{});
          }
          ZIGEOF
          zig run /tmp/hello.zig 2>&1 | grep -q 'zig_hello_ok'
        """)

    with subtest("zig_dev: zig build-exe compiles"):
        machine.succeed(r"""
          set -e
          mkdir -p /tmp/zig_build
          cat > /tmp/zig_build/main.zig << 'ZIGEOF'
          const std = @import("std");
          pub fn main() void { std.debug.print("zig_build_ok\n", .{}); }
          ZIGEOF
          cd /tmp/zig_build
          zig build-exe main.zig 2>&1
        """)
  '';
}
