# @path: ~/projects/configs/nix-config/tests/home/env/dev/lua/default.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::home::env::dev::lua::default
# @source: home/env/dev/lua/default.nix

{ pkgs, lib, ... }:
{
  name = "home_env_dev_lua_default";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [
      lua5_4
      lua54Packages.luarocks
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("lua_dev: lua binary present"):
        ver = machine.succeed("lua -v 2>&1").strip()
        print(f"lua: {ver}")
        assert "Lua" in ver, f"lua not found: {ver}"

    with subtest("lua_dev: luarocks present"):
        ver = machine.succeed("luarocks --version 2>&1 | head -1").strip()
        print(f"luarocks: {ver}")
        assert "LuaRocks" in ver or "luarocks" in ver.lower(), f"luarocks not found: {ver}"

    with subtest("lua_dev: execute lua script"):
        out = machine.succeed(
            "lua -e 'print(\"lua_hello_ok\")'"
        ).strip()
        assert out == "lua_hello_ok", f"lua exec failed: {out}"

    with subtest("lua_dev: lua arithmetic"):
        out = machine.succeed("lua -e 'print(1+1)'").strip()
        assert out == "2", f"lua 1+1 failed: {out}"
  '';
}
