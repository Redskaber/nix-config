# @path: ~/projects/configs/nix-config/nixos/core/srv/db/mysql.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::db::mysql - 本地 MySQL 服务配置 (开发环境)
# @usage: 初始化应用用户（首次部署时执行一次）
#   sudo mysql
#   CREATE USER 'redskaber'@'localhost' IDENTIFIED BY 'your_secure_password';
#   GRANT ALL PRIVILEGES ON dev.* TO 'redskaber'@'localhost';
#   FLUSH PRIVILEGES;
#   EXIT;
#
# @usage: 验证用户
#   mysql -u redskaber -p dev
#
# @note: 生产环境请使用 sops-nix 管理密码，开发环境可记录在 .env 文件

{ inputs
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
    enable = true;
    package = pkgs.mariadb;
    user = "mysql";
    group = "mysql";
    dataDir = "/var/lib/mysql";
    settings = {
      mysqld = {
        skip-networking     = false;                # 显式启用网络
        bind-address        = "127.0.0.1";          # 仅允许本地连接 (开发环境安全最佳实践)
        skip-name-resolve   = true;                 # 禁用 DNS 解析，加速连接
        character-set-server= "utf8mb4";
        collation-server    = "utf8mb4_unicode_ci";
        local-infile        = false;
        symbolic-links      = false;
        innodb_buffer_pool_size = "1G";             # RAM 的 25-50%
        innodb_log_file_size    = "256M";
        max_connections     = 100;
        slow_query_log      = true;
        slow_query_log_file = "/var/lib/mysql/slow.log";
        log-error           = "/var/lib/mysql/error.log";
        long_query_time     = 2;                    # 记录超过 2 秒的查询
        secure-file-priv    = config.sops.secrets."nixos/srv/db/mysql/users/kilig/password".path;
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
        name = "kilig";
        ensurePermissions = {
          "dev.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };


  # 专用服务：仅处理密码（运行时安全注入）
  systemd.services.mysql-set-passwords = {
    description = "Securely set MySQL user passwords from sops secrets";
    after = [ "mysql.service" ];
    requires = [ "mysql.service" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [ mariadb ];
    script = ''
      # 检查是否已设置密码(如果需要已经存在就不再设置则取消注释)
      # if [ -f /var/lib/mysql/.passwords_set ]; then
      #   exit 0
      # fi

      # 等待 MySQL 就绪
      while ! mysqladmin ping -u root --silent 2>/dev/null; do
        sleep 0.5
      done

      # 安全读取密码
      kilig_pwd=$(tr -d '\n' < ${config.sops.secrets."nixos/srv/db/mysql/users/kilig/password".path})

      # 安全设置密码
      mysql -u root <<SQL_EOF
      ALTER USER 'kilig'@'localhost'
        IDENTIFIED VIA mysql_native_password
        USING PASSWORD('$kilig_pwd');
      FLUSH PRIVILEGES;
      SELECT '✅ Passwords secured' AS status;
      SQL_EOF

      # 创建标记文件
      touch /var/lib/mysql/.passwords_set
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
      Environment = "MYSQL_PWD=";
      PrivateTmp = true;
      # 最小权限文件系统视图
      ReadOnlyDirectories = [ "/" ];
      # 阻止密码出现在 systemd 日志
      StandardOutput = "journal";
      StandardError = "journal";
      ReadWritePaths = [
        "/var/lib/mysql"
        "/run/mysqld"
      ];
      ReadOnlyPaths = [ config.sops.secrets."nixos/srv/db/mysql/users/kilig/password".path ];
    };
    unitConfig.RequiresMountsFor = [ config.sops.secrets."nixos/srv/db/mysql/users/kilig/password".path ];
  };


}


