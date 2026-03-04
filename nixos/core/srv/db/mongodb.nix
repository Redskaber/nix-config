# @path: ~/projects/configs/nix-config/nixos/core/srv/db/mongodb.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::db::mongodb
# @deploy: 首次部署后验证:
#   > mongosh "mongodb://<user>:<pwd>@<host>/admin"
#
#   mongosh -u root -p <pwd> --authenticationDatabase admin
#   use admin
#   db.createUser({user:"<user>", pwd:"<pwd>", roles:[{role:"readWrite", db:"<db>"}]})
#
# @reset: 重置数据库（开发环境）:
#   sudo systemctl stop mongodb
#   sudo rm -rf /var/lib/mongodb /var/lib/mongodb-secrets/root-password
#   sudo systemctl start mongodb  # 会重新读取 initialRootPasswordFile
#
# @prod: 生产环境必须:
#   1. 使用 sops-nix 管理密码
#   2. 将 initialRootPasswordFile 指向 /run/secrets/mongodb-root
#   3. 通过 systemd 服务在启动时解密到内存文件系统


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [ mongodb-ce mongosh ];

  services.mongodb = {
    enable = true;
    package = pkgs.mongodb-ce;
    mongoshPackage = pkgs.mongosh;
    user = "mongodb";
    bind_ip = "127.0.0.1";
    quiet = false;
    enableAuth = true;
    dbpath = "/var/lib/mongodb";
    initialRootPasswordFile = config.sops.secrets."nixos/srv/db/mongodb/password".path;

    # pidFile = "/run/mongodb.pid";
    # replSetName = "<name>";
    # extraConfig = "<yaml-config>";
  };

  # User `mongodb` visited /run/secrets => 'keys'
  users.users.mongodb.extraGroups = [ "keys" ];

}


