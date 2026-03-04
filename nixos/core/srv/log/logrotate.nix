# @path: ~/projects/configs/nix-config/nixos/core/srv/log/logrotate.nix
# @author: redskaber
# @datetime: 2026-02-24
# @directory: https://search.nixos.org/options?channel=25.11&query=services.logrotate
# @description: nixos::core::srv::log::logrotate
# - logrotate.service is a log rotation service based on the logrotate tool in Linux systems.
# - It is usually executed on a schedule via cron/anacron to automatically split, compress,
# - and delete old logs to prevent the disk from being filled with log files.

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [ logrotate ];

  services.logrotate = {
    enable = true;
    checkConfig = true;
    allowNetworking = false;
    settings = {
                                    # 全局头配置
      header = {
        priority = 1000;            # 确保最先应用
        su = "root root";           # 以 root 身份操作文件
        create = "0640 root adm";   # 新日志文件权限
        dateext = true;             # 使用日期扩展名而非数字
        dateformat = "-%Y%m%d";     # 标准化日期格式
        compress = true;            # 默认启用压缩
        delaycompress = true;       # 延迟压缩，确保应用释放文件
        missingok = true;           # 文件不存在时不报错
        notifempty = true;          # 空文件不轮转
        maxage = 30;                # 默认保留30天
      };
                                    # MySQL 日志轮转
      mysql = {
        enable = true;
        priority = 1001;
        global = false;
        files = [
          "/var/lib/mysql/error.log"
          "/var/lib/mysql/slow.log"
        ];   # 显式文件列表
        frequency = "daily";                  # null or string
      };
                                    # PostgreSQL 日志轮转
      postgresql = {
        enable = true;
        priority = 1002;                      # S->E: 1000, 1001, 1002
        global = false;
                                              # 仅处理历史日志文件（排除当前活跃文件）
        files = [ "/var/lib/postgresql/*/log/postgresql-*.log" ];
        frequency = "weekly";                 # null or string
      };
      # Mongodb -> journalctl
      # Redis   -> null
    };

  };


}


