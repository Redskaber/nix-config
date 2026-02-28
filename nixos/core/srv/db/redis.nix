# @path: ~/projects/configs/nix-config/nixos/core/srv/db/redis.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::db::redis
# @usage:
#   > reds-cli ping
#   PONG

{ inputs
, lib
, config
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [ redis ];

  services.redis = {
    package = pkgs.redis;
    vmOverCommit = true;
    servers = {
      # full-name: redis + <keyname>
      "server" = {
        enable = true;
        port = 6379;
        bind = "127.0.0.1";
        group = "Redis";  # auto-created
        syslog = true;
        # slaveOf = {ip=...,port=...};
        logfile = "/dev/null";
        logLevel = "notice";
        databases = 16;
        maxclients = 1024;
        # openFirewall = true;
        slowLogMaxLen = 128;
        slowLogLogSlowerThan = 10000;
      };
    };
  };

}


