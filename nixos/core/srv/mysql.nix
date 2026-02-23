# @path: ~/projects/configs/nix-config/nixos/core/srv/mysql.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::mysql - 本地 MySQL 服务配置 (开发环境)
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
  # LOGGER DIR
  systemd.tmpfiles.rules = [
    "d /var/log/mysql 0750 mysql mysql - -"
  ];

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
        slow_query_log_file = "/var/log/mysql/slow.log";
        log-error           = "/var/log/mysql/error.log";
        long_query_time     = 2;                    # 记录超过 2 秒的查询
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
    # 系统用户权限
    ensureUsers = [
      {
        name = "kilig";
        ensurePermissions = {
          "dev.*" = "ALL PRIVILEGES";
          "*.*" = "PROCESS";                # 允许查看进程
        };
      }
    ];
  };


}


