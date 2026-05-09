# @path: ~/projects/configs/nix-config/tests/nixos/core/srv/db/mongodb.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::srv::db::mongodb
# @source: nixos/core/srv/db/mongodb.nix
#
# Mirrors production config (enableAuth=false for test isolation):
#   services.mongodb.package = pkgs.mongodb-ce
#   bind_ip = "127.0.0.1"
#   port 27017

{ pkgs, lib, ... }:
{
  name = "nixos_core_srv_db_mongodb";
  meta = { maintainers = [ "redskaber" ]; timeout = 300; };

  nodes.machine = {
    virtualisation.memorySize = 1536;

    services.mongodb = {
      enable     = true;
      package    = pkgs.mongodb-ce;
      bind_ip    = "127.0.0.1";
      enableAuth = false;   # no sops in unit tests
      quiet      = false;
      dbpath     = "/var/lib/mongodb";
    };

    environment.systemPackages = with pkgs; [ mongodb-ce mongosh ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("mongodb.service")

    with subtest("mongodb: service active"):
        st = machine.succeed("systemctl is-active mongodb").strip()
        assert st == "active", f"mongodb not active: {st}"

    with subtest("mongodb: listening on 27017"):
        machine.wait_until_succeeds("ss -tlnp | grep ':27017'", timeout=60)
        out = machine.succeed("ss -tlnp | grep ':27017'").strip()
        assert ":27017" in out

    with subtest("mongodb: mongosh ping"):
        out = machine.succeed(
            "mongosh --quiet --eval \"db.adminCommand({ping:1})\" 2>&1"
        ).strip()
        print(f"ping: {out}")
        assert "ok" in out.lower() or "1" in out

    with subtest("mongodb: insert/find round-trip"):
        machine.succeed(
            "mongosh --quiet --eval \""
            "db.getSiblingDB('nixtest').health.insertOne({status:'ok'});\""
            " 2>&1"
        )
        out = machine.succeed(
            "mongosh --quiet --eval \""
            "db.getSiblingDB('nixtest').health.findOne({status:'ok'}).status;\""
            " 2>&1"
        ).strip()
        print(f"find: {out}")
        assert "ok" in out
  '';
}
