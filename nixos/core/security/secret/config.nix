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

{ inputs
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ../../../../secrets/secrets.yaml;     # relave path (current file)
    age.generateKey = true;
    age.keyFile = "/home/kilig/.config/sops/age/keys.txt";  # age publish key file position
    age.sshKeyPaths = [ ];
    secrets."nixos/users/kilig/password" = {                # ps: value-type don't numbers
      mode = "0440";
      owner = config.users.users.kilig.name;
      group = config.users.users.kilig.group;
      path = "/home/kilig/.config/sops/age/serects/nixos/users/kilig/password";  # ref-link save position; default-path: /run/<fileName>/<secrets_key>
    };
  };

}


