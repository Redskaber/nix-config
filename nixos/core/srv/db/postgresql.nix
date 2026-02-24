# @path: ~/projects/configs/nix-config/nixos/core/srv/db/postgresql.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::db::postgresql
# @deploy: 验证安装:
#   psql -U kilig -d dev -c "\dt"
#   psql -h 127.0.0.1 -U redskaber -d dev -W   # 密码=1024
#
# @reset: 重置数据库（开发环境）:
#   sudo systemctl stop postgresql
#   sudo rm -rf /var/lib/postgresql/${config.services.postgresql.package.psqlSchema}
#   sudo systemctl start postgresql  # 自动重新初始化
#
# @schema: 应用初始化:
#   1. 应用启动时自动运行 migrations（推荐）
#   2. 手动执行: psql -U redskaber -d dev < schema.sql
#
# @prod: 生产环境必须:
#   1. 替换 initialScript 中的明文密码为 sops-nix 管理
#   2. 删除 127.0.0.1/32 trust 规则
#   3. 使用 Let's Encrypt 证书替换自签名证书
#   4. 限制 max_connections 并调整内存参数
#
# @warning: 证书生成（仅开发环境）:
#   openssl req -new -x509 -days 365 -nodes -text -out server.crt \
#     -keyout server.key -subj "/CN=localhost" -addext "subjectAltName = DNS:localhost"
#   chmod 600 server.key
#   sudo chown postgres:postgres server.*
#
# @fix-ssl: 生成开发证书（首次部署）:
#   cd ~/projects/configs/nix-config/nixos/core/srv
#   openssl req -new -x509 -days 365 -nodes -text -out server.crt \
#     -keyout server.key -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost"
#   chmod 600 server.key
#   # 取消注释 systemd.tmpfiles.rules 和 settings.ssl 相关行
#
# @verify: 验证部署:
#   psql -U kilig -d kilig -c "SELECT current_user;"          # peer 认证（无密码）
#   psql -h 127.0.0.1 -U redskaber -d dev -W                  # TCP + 密码认证(1024)
#
# @reset: 重置数据库（开发环境）:
#   sudo systemctl stop postgresql
#   sudo rm -rf /var/lib/postgresql/${config.services.postgresql.package.psqlSchema}
#   sudo systemctl start postgresql


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  # 创建 SSL 证书（开发环境自签名，生产环境应替换）
  # systemd.tmpfiles.rules = [
  #   "d /var/lib/postgresql 0700 postgres postgres - -"
  #   "f /var/lib/postgresql/server.crt 0600 postgres postgres - ${builtins.readFile ./server.crt}"
  #   "f /var/lib/postgresql/server.key 0600 postgres postgres - ${builtins.readFile ./server.key}"
  # ];

  environment.systemPackages = with pkgs; [ postgresql ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql;
    dataDir = "/var/lib/postgresql/${config.services.postgresql.package.psqlSchema}";
    enableJIT = true;     # 性能优化
    enableTCPIP = true;   # Allow TCP
    checkConfig = true;   # 编译检查配置

    # 核心配置
    settings = {
      # 连接设置
      listen_addresses = lib.mkForce "127.0.0.1";  # 仅本地访问（生产环境可扩展）
      port = 5432;
      max_connections = 128;

      # 认证设置
      password_encryption = "scram-sha-256";  # 现代密码哈希算法

      # 内存设置
      shared_buffers = "128MB";               # 约为系统内存的 25%
      effective_cache_size = "384MB";
      work_mem = "4MB";
      maintenance_work_mem = "64MB";

      # WAL 和检查点
      wal_level = "replica";
      checkpoint_completion_target = 0.9;
      wal_buffers = "3.9MB";

      # 查询规划
      default_statistics_target = 100;
      random_page_cost = 1.1;                   # SSD 优化

      # 日志（开发环境详细，生产环境精简）
      logging_collector = true;
      log_filename = "postgresql-%Y-%m-%d.log";
      log_truncate_on_rotation = true;
      log_rotation_age = "1d";
      log_statement = "ddl";                    # 生产环境应为 "ddl"，调试环境可设为 "all"
      log_line_prefix = "%m [%p] %q%u@%d ";     # 丰富日志前缀
      log_timezone = "Asia/Shanghai";

      # 本地化
      default_text_search_config = "pg_catalog.english";

      # 安全设置
      # ssl = "on";  # 启用 SSL（即使本地连接）
      # ssl_cert_file = "/var/lib/postgresql/server.crt";
      # ssl_key_file = "/var/lib/postgresql/server.key";
    };

    # 认证配置：精确控制访问（pg_hba.conf）
    # @note: 规则顺序很重要！先匹配的规则生效
    authentication = lib.mkOverride 10 ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      # 本地 peer 认证（无密码）
      local   all             all                                     peer
      # 本地 IPv4/IPv6 连接（使用 scram-sha-256 密码认证）
      host    all             all             127.0.0.1/32            scram-sha-256
      host    all             all             ::1/128                 scram-sha-256
    '';

    # 初始化脚本：创建应用用户和数据库（幂等）
    # @note: 此脚本仅在首次初始化时执行
    initialScript = pkgs.writeText "app-init.sql" ''
      -- 创建应用用户（密码=1024，仅开发环境！）
      DO $$ BEGIN
        CREATE USER redskaber WITH PASSWORD '1024' NOSUPERUSER NOCREATEDB NOCREATEROLE;
      EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'User redskaber already exists.';
      END $$;

      -- 创建数据库
      CREATE DATABASE dev
        OWNER redskaber
        ENCODING 'UTF8'
        LC_COLLATE 'en_US.UTF-8'
        LC_CTYPE 'en_US.UTF-8'
        TEMPLATE template0;

      \c dev

      -- 启用内置扩展
      CREATE EXTENSION IF NOT EXISTS pg_trgm;     -- 模糊搜索
      CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; -- UUID 生成
      CREATE EXTENSION IF NOT EXISTS vector;      -- 向量搜索 (pgvector)

      -- 授予权限
      GRANT ALL PRIVILEGES ON SCHEMA public TO redskaber;

      -- 创建示例表
      CREATE TABLE IF NOT EXISTS health_check (
        id SERIAL PRIMARY KEY,
        status TEXT NOT NULL DEFAULT 'ok',
        checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      INSERT INTO health_check (status) VALUES ('NixOS PostgreSQL 配置成功!');

      -- 验证
      SELECT 'Initialization completed successfully!' AS status;
    '';

    # 确保关键数据库存在（即使 initialScript 失败）
    ensureDatabases = [ "kilig" ];

    # 确保系统用户可访问（peer 认证）
    ensureUsers = [
      {
        name = "kilig";  # 当前系统用户名
        ensureDBOwnership = true;
        ensureClauses = {
          login = true;
          createdb = true;  # 允许创建数据库
        };
      }
      {
        name = "redskaber";
        ensureDBOwnership = false;
        ensureClauses = {
          login = true;
          # 无 createdb/createrole 权限（最小权限原则）
        };
      }
    ];

    # 第三方扩展
    # 内置扩展 (pg_trgm/uuid-ossp) 由 postgresql-contrib 提供
    extensions = ps: with ps; [
      pgvector   # 向量搜索（AI 应用）
    ];

    # initdb 额外参数（增强可靠性）
    initdbArgs = [
      "--locale=en_US.UTF-8"
      "--encoding=UTF8"
      "--data-checksums"  # 启用数据校验（防止静默损坏）
      "--auth-host=scram-sha-256"
      "--auth-local=peer"
    ];

    # ident 映射：允许系统用户映射到 DB 用户
    identMap = ''
      # MapName       SystemUser      DBUser
      superuser_map    root            postgres
      superuser_map    kilig           kilig      # 系统用户 kilig      → DB 用户 kilig
      # appuser_map      redskaber       redskaber  # 系统用户 redskaber  → DB 用户 redskaber
    '';

    # 系统调用过滤（增强安全性，生产环境必需）
    systemCallFilter = {
      default       = true;   # 启用默认过滤
      "@network-io" = true;   # 允许网络 IO
      "@file-system"= true;   # 允许文件系统访问
      "@clock"      = true;   # 允许时钟访问
      "@privileged" = false;
      "@debug"      = false;
      "@module"     = false;
    };
  };


}


