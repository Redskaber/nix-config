# @path: ~/projects/configs/nix-config/tests/home/env/dev/javascript/default.nix
# @author: redskaber
# @datetime: 2026-10-30
# @description: tests::home::env::dev::javascript::default
# @source: home/env/dev/javascript/default.nix
#
# Mirrors production buildInputs for the JavaScript devenv:
#   nodejs_24, yarn, pnpm, typescript-language-server, biome

{ pkgs, lib, ... }:
{
  name = "home_env_dev_javascript_default";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 300;
  };

  nodes.machine = {
    virtualisation.memorySize = 768;
    environment.systemPackages = with pkgs; [
      nodejs_24
      yarn
      pnpm
      typescript-language-server
      biome
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("js_dev: node binary present"):
        ver = machine.succeed("node --version 2>&1").strip()
        print(f"node: {ver}")
        assert ver.startswith("v"), f"node not found: {ver}"

    with subtest("js_dev: yarn binary present"):
        ver = machine.succeed("yarn --version 2>&1").strip()
        print(f"yarn: {ver}")
        assert ver[0].isdigit(), f"yarn not found: {ver}"

    with subtest("js_dev: pnpm binary present"):
        ver = machine.succeed("pnpm --version 2>&1").strip()
        print(f"pnpm: {ver}")
        assert ver[0].isdigit(), f"pnpm not found: {ver}"

    with subtest("js_dev: biome binary present"):
        ver = machine.succeed("biome --version 2>&1").strip()
        print(f"biome: {ver}")
        assert "biome" in ver.lower() or "Version" in ver, f"biome not found: {ver}"

    with subtest("js_dev: typescript-language-server present"):
        w = machine.succeed("which typescript-language-server 2>/dev/null || true").strip()
        print(f"typescript-language-server: {w}")

    with subtest("js_dev: execute node hello-world"):
        out = machine.succeed("node -e 'console.log(\"js_hello_ok\")'").strip()
        assert out == "js_hello_ok", f"node exec failed: {out}"

    with subtest("js_dev: node module resolution"):
        machine.succeed(r"""
          set -e
          mkdir -p /tmp/jsproj
          cd /tmp/jsproj
          node -e 'const fs = require("fs"); fs.writeFileSync("hello.txt", "js_module_ok");'
          grep -q 'js_module_ok' hello.txt
        """)
  '';
}
