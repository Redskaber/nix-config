# @path: ~/projects/configs/nix-config/tests/nixos/core/srv/db/postgresql.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::srv::db::postgresql
# @source: nixos/core/srv/db/postgresql.nix
#
# Mirrors production config (sops secrets replaced with ensureUsers for test isolation):
#   services.postgresql.enable = true
#   enableTCPIP = true
#   port = 5432
#   authentication: local peer + host scram-sha-256
#   ensureDatabases / ensureUsers
#   initialScript → health_check table

{ pkgs, lib, ... }:
let
  testUser = "pgtest";
in
{
  name = "nixos_core_srv_db_postgresql";
  meta = { maintainers = [ "redskaber" ]; timeout = 300; };

  nodes.machine = {
    virtualisation.memorySize = 1024;

    services.postgresql = {
      enable      = true;
      package     = pkgs.postgresql;
      enableTCPIP = true;

      settings = {
       listen_addresses     = lib.mkForce "127.0.0.1";
        port                = 5432;
        max_connections     = 64;
        password_encryption = "scram-sha-256";
        shared_buffers      = "64MB";
      };

      authentication = lib.mkOverride 10 ''
        local  all  all                    peer
        host   all  all   127.0.0.1/32     scram-sha-256
      '';

      initialScript = pkgs.writeText "pg-init.sql" ''
        CREATE TABLE IF NOT EXISTS health_check (
          id         SERIAL PRIMARY KEY,
          status     TEXT NOT NULL DEFAULT 'ok',
          checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        INSERT INTO health_check (status) VALUES ('nixos-pg-test-ok');
      '';

      ensureDatabases = [ testUser ];
      ensureUsers = [
        {
          name              = testUser;
          ensureDBOwnership = true;
          ensureClauses     = { login = true; };
        }
      ];
    };

    environment.systemPackages = with pkgs; [ postgresql ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("postgresql.service")

    with subtest("postgresql: service active"):
        st = machine.succeed("systemctl is-active postgresql").strip()
        assert st == "active", f"postgresql not active: {st}"

    with subtest("postgresql: listening on 5432"):
        machine.wait_until_succeeds("ss -tlnp | grep ':5432'", timeout=60)
        out = machine.succeed("ss -tlnp | grep ':5432'").strip()
        assert ":5432" in out

    with subtest("postgresql: peer auth for postgres user"):
        out = machine.succeed(
            "sudo -u postgres psql -c 'SELECT version();' 2>&1"
        ).strip()
        print(f"version: {out[:80]}")
        assert "PostgreSQL" in out

    with subtest("postgresql: ensureDatabase ${testUser} exists"):
        dbs = machine.succeed(
            "sudo -u postgres psql -lqt 2>&1 | cut -d'|' -f1 | tr -d ' '"
        ).strip()
        print(f"databases: {dbs}")
        assert "${testUser}" in dbs, f"DB ${testUser} not found: {dbs}"

    with subtest("postgresql: ensureUser ${testUser} exists"):
        users = machine.succeed(
            "sudo -u postgres psql -c '\\du' 2>&1"
        ).strip()
        assert "${testUser}" in users, f"User ${testUser} not found"

    with subtest("postgresql: health_check table queryable"):
        out = machine.succeed(
            "sudo -u postgres psql -d postgres"
            " -c 'SELECT status FROM health_check LIMIT 1;' 2>&1"
        ).strip()
        print(f"health_check: {out}")
        assert "nixos-pg-test-ok" in out or "1 row" in out
  '';
}
