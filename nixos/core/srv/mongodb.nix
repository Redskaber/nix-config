# @path: ~/projects/configs/nix-config/nixos/core/srv/mongodb.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::mongodb
# @deploy: 首次部署后验证:
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
, lib
, config
, pkgs
, ...
}:
let
  # 开发环境密码（明文仅用于演示！生产环境必须用 sops-nix）
  devRootPassword = "1024";    # ← 请替换为强密码
in
{
  # 创建密码文件（systemd-tmpfiles 确保权限安全）
  systemd.tmpfiles.rules = [
    # 创建 secrets 目录（仅 mongodb 用户可访问）
    "d /var/lib/mongodb-secrets 0700 mongodb mongodb - -"
    # 创建密码文件（内容=devRootPassword，权限 600）
    "f /var/lib/mongodb-secrets/root-password 0600 mongodb mongodb - ${devRootPassword}"
  ];

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
    initialRootPasswordFile = "/var/lib/mongodb-secrets/root-password";

    # pidFile = "/run/mongodb.pid";
    # replSetName = "<name>";
    # extraConfig = "<yaml-config>";
  };


}


