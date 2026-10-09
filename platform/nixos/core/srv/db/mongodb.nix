# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/db/mongodb.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: platform::nixos::system::core::srv::db::mongodb
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

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  environment.systemPackages = lib.optionals shared.services.db.mongodb.install (
    with pkgs;
    [
      mongodb-ce
      mongosh
    ]
  );

  services.mongodb = {
    enable = shared.services.db.mongodb.install;
    package = pkgs.mongodb-ce;
    mongoshPackage = pkgs.mongosh;
    user = "mongodb";
    bind_ip = "127.0.0.1";
    quiet = false;
    enableAuth = true;
    dbpath = "/var/lib/mongodb";
    initialRootPasswordFile =
      config.sops.secrets.${shared.secrets.nixos.core.srv.db.mongodb.user.password}.path;

    # pidFile = "/run/mongodb.pid";
    # replSetName = "<name>";
    # extraConfig = "<yaml-config>";
  };

  # User `mongodb` visited /run/secrets => 'keys'
  # (option-level mkIf: gating only the leaf value still registers the
  # `mongodb` key inside the users.users attrsOf and materialises an
  # incomplete user on hosts that do not install this db — found by the
  # second-machine evaluation of the server-pg-only profile.)
  users.users = lib.mkIf shared.services.db.mongodb.install {
    mongodb.extraGroups = [ "keys" ];
  };

  # Control autostart: clear wantedBy when autostart=false (install but not autostart)
  systemd.services = lib.mkIf shared.services.db.mongodb.install {
    # T4.0: binding selection from service-profile strategy data —
    # lib.optional, the same idiom virtual.nix uses (branchless).
    mongodb.wantedBy = lib.mkForce (
      lib.optional shared.services.db.mongodb.autostart "multi-user.target"
    );
  };
}
