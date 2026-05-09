# @path: ~/projects/configs/nix-config/tests/nixos/core/srv/db/redis.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::srv::db::redis
# @source: nixos/core/srv/db/redis.nix
#
# Mirrors production config:
#   services.redis.servers."".enable = true
#   bind = "127.0.0.1"
#   port = 6379

{ pkgs, lib, ... }:
{
  name = "nixos_core_srv_db_redis";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 512;

    services.redis.servers."" = {
      enable = true;
      bind   = "127.0.0.1";
      port   = 6379;
      save   = [];   # disable persistence for speed
    };

    environment.systemPackages = with pkgs; [ redis ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("redis.service")

    with subtest("redis: service active"):
        st = machine.succeed("systemctl is-active redis").strip()
        assert st == "active", f"redis not active: {st}"

    with subtest("redis: PING → PONG"):
        pong = machine.succeed("redis-cli PING").strip()
        print(f"PING -> {pong}")
        assert pong == "PONG", f"Expected PONG, got: {pong}"

    with subtest("redis: SET/GET round-trip"):
        machine.succeed("redis-cli SET nixtest_key 'hello_redis'")
        val = machine.succeed("redis-cli GET nixtest_key").strip()
        print(f"GET nixtest_key = {val}")
        assert val == "hello_redis", f"Unexpected GET: {val}"

    with subtest("redis: DEL removes key"):
        machine.succeed("redis-cli DEL nixtest_key")
        val = machine.succeed("redis-cli GET nixtest_key").strip()
        assert val == "", f"Key not deleted: {val}"

    with subtest("redis: bound to 127.0.0.1"):
        cfg = machine.succeed("redis-cli CONFIG GET bind").strip()
        print(f"bind: {cfg}")
        assert "127.0.0.1" in cfg
  '';
}
