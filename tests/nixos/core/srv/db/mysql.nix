# @path: ~/projects/configs/nix-config/tests/nixos/core/srv/db/mysql.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::srv::db::mysql
# @source: nixos/core/srv/db/mysql.nix
#
# Mirrors production config (sops replaced with initialScript for test isolation):
#   services.mysql.package = pkgs.mariadb
#   bind_address = 127.0.0.1
#   port = 3306
#   ensureDatabases / ensureUsers

{ pkgs, lib, ... }:
let
  testUser = "mysqltest";
  testDb   = "devtest";
in
{
  name = "nixos_core_srv_db_mysql";
  meta = { maintainers = [ "redskaber" ]; timeout = 300; };

  nodes.machine = {
    virtualisation.memorySize = 1024;

    services.mysql = {
      enable  = true;
      package = pkgs.mariadb;

      settings.mysqld = {
        bind_address    = "127.0.0.1";
        port            = 3306;
        max_connections = 64;
      };

      ensureDatabases = [ testDb ];
      ensureUsers = [
        {
          name = testUser;
          ensurePermissions."${testDb}.*" = "ALL PRIVILEGES";
        }
      ];

      initialScript = pkgs.writeText "mysql-init.sql" ''
        CREATE DATABASE IF NOT EXISTS ${testDb};
        USE ${testDb};
        CREATE TABLE IF NOT EXISTS health_check (
          id     INT AUTO_INCREMENT PRIMARY KEY,
          status VARCHAR(64) NOT NULL DEFAULT 'ok'
        );
        INSERT INTO health_check (status) VALUES ('nixos-mysql-test-ok');
      '';
    };

    environment.systemPackages = with pkgs; [ mariadb ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("mysql.service")

    with subtest("mysql: service active"):
        st = machine.succeed("systemctl is-active mysql").strip()
        assert st == "active", f"mysql not active: {st}"

    with subtest("mysql: root socket auth works"):
        out = machine.succeed(
            "sudo -u mysql mysql -e 'SELECT VERSION();' 2>&1"
        ).strip()
        print(f"mysql version: {out}")
        assert any(v in out for v in ["MariaDB", "8.", "5."]), \
            f"Unexpected mysql output: {out}"

    with subtest("mysql: database ${testDb} exists"):
        dbs = machine.succeed(
            "sudo -u mysql mysql -e 'SHOW DATABASES;' 2>&1"
        ).strip()
        assert "${testDb}" in dbs, f"DB ${testDb} not found: {dbs}"

    with subtest("mysql: user ${testUser} exists"):
        users = machine.succeed(
            "sudo -u mysql mysql -e"
            " \"SELECT User FROM mysql.user WHERE User='${testUser}';\" 2>&1"
        ).strip()
        assert "${testUser}" in users, "User ${testUser} not found"

    with subtest("mysql: health_check table queryable"):
        out = machine.succeed(
            "sudo -u mysql mysql ${testDb}"
            " -e 'SELECT status FROM health_check LIMIT 1;' 2>&1"
        ).strip()
        print(f"health_check: {out}")
        assert "nixos-mysql-test-ok" in out
  '';
}
