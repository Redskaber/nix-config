# @path: ~/projects/configs/nix-config/nixos/core/srv/db/mongodb.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::db::mongodb
# @deploy: verify after first deployment:
#   > mongosh "mongodb://<user>:<pwd>@<host>/admin"
#
#   mongosh -u root -p <pwd> --authenticationDatabase admin
#   use admin
#   db.createUser({user:"<user>", pwd:"<pwd>", roles:[{role:"readWrite", db:"<db>"}]})
#
# @reset: reset database (dev environment):
#   sudo systemctl stop mongodb
#   sudo rm -rf /var/lib/mongodb /var/lib/mongodb-secrets/root-password
# sudo systemctl start mongodb # initialRootPasswordFile
#
# @prod: production environment requires:
#   1. use sops-nix managedpassword
#   2. initialRootPasswordFile /run/secrets/mongodb-root
#   3. via systemd serviceinstart toinsidefilesystem


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
    enable = shared.services.db.mongodb.install;
    package = pkgs.mongodb-ce;
    mongoshPackage = pkgs.mongosh;
    user = "mongodb";
    bind_ip = "127.0.0.1";
    quiet = false;
    enableAuth = true;
    dbpath = "/var/lib/mongodb";
    initialRootPasswordFile = config.sops.secrets.${shared.secrets.nixos.core.srv.db.mongodb.user.password}.path;

    # pidFile = "/run/mongodb.pid";
    # replSetName = "<name>";
    # extraConfig = "<yaml-config>";
  };

  # User `mongodb` visited /run/secrets => 'keys'
  users.users.mongodb.extraGroups = [ "keys" ];


  # Control autostart: clear wantedBy when autostart=false (install but not autostart)
  systemd.services.mongodb.wantedBy =
    lib.mkForce (lib.optional shared.services.db.mongodb.autostart "multi-user.target");
}
