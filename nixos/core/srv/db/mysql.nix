# @path: ~/projects/configs/nix-config/nixos/core/srv/db/mysql.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::db::mysql - local MySQL service config (dev environment)
# @usage: initialize application user (run once on first deploy)
#   sudo mysql
#   CREATE USER 'redskaber'@'localhost' IDENTIFIED BY 'your_secure_password';
#   GRANT ALL PRIVILEGES ON dev.* TO 'redskaber'@'localhost';
#   FLUSH PRIVILEGES;
#   EXIT;
#
# @usage: verify user
#   mysql -u redskaber -p dev
#
# @note: use sops-nix for password in production; dev env can record in .env file

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  # MYSQL VERSION
  environment.systemPackages = with pkgs; [
    # mysql84   # unfree
    mariadb     # free
  ];


  # MYSQLD SERVICES
  services.mysql = {
    enable = shared.services.db.mysql.install;
    package = pkgs.mariadb;
    user = "mysql";
    group = "mysql";
    dataDir = "/var/lib/mysql";
    settings = {
      mysqld = {
        skip-networking     = false;        # enable
        bind-address        = "127.0.0.1";  # only allow (dev environmentsecure)
        skip-name-resolve   = true;         # disable DNS ，
        character-set-server= "utf8mb4";
        collation-server    = "utf8mb4_unicode_ci";
        local-infile        = false;
        symbolic-links      = false;
        innodb_buffer_pool_size = "1G";     # RAM 25-50%
        innodb_log_file_size    = "256M";
        max_connections     = 100;
        slow_query_log      = true;
        slow_query_log_file = "/var/lib/mysql/slow.log";
        log-error           = "/var/lib/mysql/error.log";
        long_query_time = 2;                # 记录超过 2 秒的查询
        secure-file-priv    = config.sops.secrets.${shared.secrets.nixos.core.srv.db.mysql.root.password}.path;
      };
      client = {
        default-character-set = "utf8mb4";
      };
      mysqldump = {
        quick = true;
        max_allowed_packet = "64M";
      };
    };
    ensureDatabases = [ "dev" ];
    ensureUsers = [
      {
        name = shared.user.username;
        ensurePermissions = {
          "dev.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };


  # dedicated service：password（run secure）
  systemd.services.mysql-set-user-passwords = {
    description = "Securely set MySQL user passwords from sops secrets";
    after = [ "mysql.service" ];
    partOf = [ "mysql.service" ];
    restartIfChanged = false;
    wantedBy = lib.mkForce (
      if shared.services.db.mysql.autostart
      then [ "multi-user.target" ]
      else [ "mysql.service" ]
    );

    path = with pkgs; [ mariadb ];
    script = ''
      # Guard: 数据库没运行时跳过
      if ! systemctl is-active mysql.service 2>/dev/null; then
        echo "MySQL is not running, skipping password injection"
        exit 0
      fi

      # Wait for MySQL ready (with timeout)
      for i in $(seq 1 10); do
        mysqladmin ping -u root --silent 2>/dev/null && break
        sleep 1
      done
      if ! mysqladmin ping -u root --silent 2>/dev/null; then
        echo "MySQL not ready after 10s, skipping"
        exit 0
      fi

      # securepassword
      user_pwd=$(tr -d '\n' < ${config.sops.secrets.${shared.secrets.nixos.core.srv.db.mysql.user.password}.path})

      # security settingspassword
      mysql -u root <<SQL_EOF
      ALTER USER '${shared.user.username}'@'localhost'
        IDENTIFIED VIA mysql_native_password
        USING PASSWORD('$user_pwd');
      FLUSH PRIVILEGES;
      SELECT '✅ Passwords secured for ${shared.user.username}' AS status;
      SQL_EOF

      # create marker file
      touch /var/lib/mysql/.passwords_set
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
      Environment = "MYSQL_PWD=";
      PrivateTmp = true;
      # least privilegefilesystem
      ReadOnlyDirectories = [ "/" ];
      # passwordin systemd log
      StandardOutput = "journal";
      StandardError = "journal";
      ReadWritePaths = [
        "/var/lib/mysql"
        "/run/mysqld"
      ];
      ReadOnlyPaths = [ config.sops.secrets.${shared.secrets.nixos.core.srv.db.mysql.user.password}.path ];
    };
    unitConfig.RequiresMountsFor = [ config.sops.secrets.${shared.secrets.nixos.core.srv.db.mysql.user.password}.path ];
  };


  # Control autostart: clear wantedBy when autostart=false (install but not autostart)
  systemd.services.mysql.wantedBy =
    lib.mkForce (
      if shared.services.db.mysql.autostart
      then [ "multi-user.target" ]
      else []
    );
}
