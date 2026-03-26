# @path: ~/projects/configs/nix-config/nixos/core/sec/secret/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::sec::secret::default
#
# By default secrets are owned by root:root.
# Furthermore the parent directory /run/secrets.d is only owned by root and the keys group has read access to it.
# {
#   # Permission modes are in octal representation (same as chmod),
#   # the digits represent: user|group|others
#   # 7 - full (rwx)
#   # 6 - read and write (rw-)
#   # 5 - read and execute (r-x)
#   # 4 - read only (r--)
#   # 3 - write and execute (-wx)
#   # 2 - write only (-w-)
#   # 1 - execute only (--x)
#   # 0 - none (---)
#   sops.secrets.example-secret.mode = "0440";
#   # Either a user id or group name representation of the secret owner
#   # It is recommended to get the user name from `config.users.users.<?name>.name` to avoid misconfiguration
#   sops.secrets.example-secret.owner = config.users.users.nobody.name;
#   # Either the group id or group name representation of the secret group
#   # It is recommended to get the group name from `config.users.users.<?name>.group` to avoid misconfiguration
#   sops.secrets.example-secret.group = config.users.users.nobody.group;
# }
#
# sops-nix has to run after NixOS creates users (in order to specify what users own a secret.)
# This means that it's not possible to set users.users.<name>.hashedPasswordFile to any secrets managed by sops-nix.
# To work around this issue, it's possible to set neededForUsers = true in a secret.
# This will cause the secret to be decrypted to /run/secrets-for-users instead of /run/secrets before NixOS creates users.
# As users are not created yet, it's not possible to set an owner for these secrets.
#
# $ echo "password" | mkpasswd -s
# $y$j9T$WFoiErKnEnMcGq0ruQK4K.$4nJAY3LBeBsZBTYSkdTOejKU6KlDmhnfUV3Ll1K/1b.
#
# { config, ... }: {
#   sops.secrets.my-password.neededForUsers = true;
#
#   users.users.mic92 = {
#     isNormalUser = true;
#     hashedPasswordFile = config.sops.secrets.my-password.path;
#   };
# }
#
# | 场景 | 需要的内容 | 工具 |
# |------|------------|------|
# | Linux 系统用户密码              | `/etc/shadow` 中的 HASH | `mkpasswd -s`         |
# | MongoDB initialRootPasswordFile | 明文密码                | 直接写字符串          |
# | Nginx htpasswd                  | HASH                    | `openssl passwd -apr1`|
# | PostgreSQL pg_hba.conf          | 明文或 SCRAM            | `postgres` 命令       |
#

{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    inputs.sops-nix.nixosModules.sops                                     # import sops-nix
    ./cmd/age.nix
    ./cmd/sops.nix
    ./cmd/ssh-to-age.nix
    ./cmd/ssh-to-pgp.nix
  ];

  sops = {
    age = {
      generateKey = true;
      keyFile = "/home/${shared.user.username}/.config/sops/age/keys.txt";  # age publish key file position 600
      sshKeyPaths = shared.secrets.sshKeyPaths;
    };
    secrets = {
      ${shared.secrets.nixos.core.base.user.password} = {
        neededForUsers = true;                                            # user create before execute
        format = "yaml";
        sopsFile = ../../../../secrets/chipr/${shared.secrets.nixos.core.base.user.password}.yaml;
        mode = "0400";
        owner = config.users.users.root.name;
        group = config.users.users.root.group;
        path = "/run/secrets-for-users/${shared.secrets.nixos.core.base.user.password}";         # symlink
      };
      ${shared.secrets.nixos.core.base.nix.user.nixos-github-git-visited} = {
        format = "yaml";
        sopsFile = ../../../../secrets/chipr/${shared.secrets.nixos.core.base.nix.user.nixos-github-git-visited}.yaml;
        mode = "0400";
        owner = config.users.users.root.name;
        group = config.users.users.root.group;
        path = "/run/secrets/${shared.secrets.nixos.core.base.nix.user.nixos-github-git-visited}";
      };
      ${shared.secrets.nixos.core.srv.db.mongodb.user.password} = {
        format = "yaml";
        sopsFile = ../../../../secrets/chipr/${shared.secrets.nixos.core.srv.db.mongodb.user.password}.yaml;
        mode = "0400";
        owner = config.users.users.mongodb.name;
        group = config.users.users.mongodb.group;
        path = "/run/secrets/${shared.secrets.nixos.core.srv.db.mongodb.user.password}";           # symlink
      };
      ${shared.secrets.nixos.core.srv.db.mysql.root.password} = {
        format = "yaml";
        sopsFile = ../../../../secrets/chipr/${shared.secrets.nixos.core.srv.db.mysql.root.password}.yaml;
        mode = "0400";
        owner = config.users.users.root.name;
        group = config.users.users.root.group;
        path = "/run/secrets/${shared.secrets.nixos.core.srv.db.mysql.root.password}";
      };
      ${shared.secrets.nixos.core.srv.db.mysql.user.password} = {
        format = "yaml";
        sopsFile = ../../../../secrets/chipr/${shared.secrets.nixos.core.srv.db.mysql.user.password}.yaml;
        mode = "0440";
        owner = config.users.users.root.name;
        group = config.users.users.mysql.group;
        path = "/run/secrets/${shared.secrets.nixos.core.srv.db.mysql.user.password}";
      };
      ${shared.secrets.nixos.core.srv.db.postgresql.user.password} = {
        format = "yaml";
        sopsFile = ../../../../secrets/chipr/${shared.secrets.nixos.core.srv.db.postgresql.user.password}.yaml;
        mode = "0440";
        owner = config.users.users.root.name;
        group = config.users.users.postgres.group;
        path = "/run/secrets/${shared.secrets.nixos.core.srv.db.postgresql.user.password}";
      };
      ${shared.secrets.nixos.core.srv.db.redis.user.password} = {
        format = "yaml";
        sopsFile = ../../../../secrets/chipr/${shared.secrets.nixos.core.srv.db.redis.user.password}.yaml;
        mode = "0440";
        owner = config.users.users.root.name;
        group = config.users.users."redis-${shared.user.username}".group;
        path = "/run/secrets/${shared.secrets.nixos.core.srv.db.redis.user.password}";
      };
    };
  };


}


