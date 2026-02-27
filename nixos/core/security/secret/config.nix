# @path: ~/projects/configs/nix-config/nixos/core/security/secret/config.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::security::secret::config
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

{ inputs
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    inputs.sops-nix.nixosModules.sops                           # import sops-nix
  ];

  sops = {
    defaultSopsFile = ../../../../secrets/secrets.yaml;         # relave path (current file)
    age.generateKey = true;
    age.keyFile = "/home/kilig/.config/sops/age/keys.txt";      # age publish key file position
    age.sshKeyPaths = [ "/home/kilig/.ssh/id_ed25519_github" ]; # ssh key path
    secrets."nixos/users/kilig/password" = {
      neededForUsers = true;                                    # user create before execute
      mode = "0400";
      owner = config.users.users.kilig.name;
      group = config.users.users.kilig.group;
      path = "/home/kilig/.config/sops/age/serects/nixos/users/kilig/password";   # symlink
    };
  };

}


