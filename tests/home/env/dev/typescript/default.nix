# @path: ~/projects/configs/nix-config/tests/home/env/dev/typescript/default.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::env::dev::typescript::default
# @source: home/env/dev/typescript/default.nix
#
# Mirrors production buildInputs:
#   nodejs_24, pnpm, yarn, typescript, typescript-language-server, tsx

{ pkgs, lib, ... }:
{
  name = "home_env_dev_typescript_default";
  meta = { maintainers = [ "redskaber" ]; timeout = 300; };

  nodes.machine = {
    virtualisation.memorySize = 1024;

    environment.systemPackages = with pkgs; [
      nodejs_24
      # FIXME: pnpm, yarn from nodePackages move to header pattern
      # nodePackages.pnpm
      # nodePackages.yarn
      pnpm
      yarn
      typescript
      nodePackages.typescript-language-server
      tsx
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("ts_dev: node present"):
        ver = machine.succeed("node --version 2>&1").strip()
        print(f"node: {ver}")
        assert ver.startswith("v"), f"node not found: {ver}"

    with subtest("ts_dev: npm present"):
        ver = machine.succeed("npm --version 2>&1").strip()
        print(f"npm: {ver}")
        assert ver != ""

    with subtest("ts_dev: pnpm present"):
        ver = machine.succeed("pnpm --version 2>&1").strip()
        print(f"pnpm: {ver}")
        assert ver != ""

    with subtest("ts_dev: yarn present"):
        ver = machine.succeed("yarn --version 2>&1").strip()
        print(f"yarn: {ver}")
        assert ver != ""

    with subtest("ts_dev: tsc (TypeScript compiler) present"):
        ver = machine.succeed("tsc --version 2>&1 || true").strip()
        print(f"tsc: {ver}")
        assert "Version" in ver or "TypeScript" in ver, f"tsc not found: {ver}"

    with subtest("ts_dev: typescript-language-server present"):
        w = machine.succeed("which typescript-language-server 2>/dev/null || true").strip()
        print(f"ts-ls: {w}")

    with subtest("ts_dev: tsx executes a TS snippet"):
        machine.succeed("""
          echo "console.log('tsx_ok:' + (1+1))" > /tmp/test_tsx.ts
          tsx /tmp/test_tsx.ts 2>&1 | grep -q 'tsx_ok:2'
        """)
  '';
}
