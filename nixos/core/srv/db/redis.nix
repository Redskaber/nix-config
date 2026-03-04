# @path: ~/projects/configs/nix-config/nixos/core/srv/db/redis.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::db::redis
# @usage:
#   > reds-cli ping
#   PONG

{ inputs
, shared
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
      # full-name: redis + <-keyname>
      "server" = {
        enable = true;
        port = 6379;
        bind = "127.0.0.1";
        user =  "redis-server";
        group = "redis-server";  # auto-created => full-name
        syslog = true;
        # slaveOf = {ip=...,port=...};
        logfile = "/dev/null";
        logLevel = "notice";
        databases = 16;
        maxclients = 1024;
        # openFirewall = true;
        slowLogMaxLen = 128;
        slowLogLogSlowerThan = 10000;
        requirePassFile = config.sops.secrets."nixos/srv/db/redis/users/redis-server/password".path;
      };
    };
  };

}


