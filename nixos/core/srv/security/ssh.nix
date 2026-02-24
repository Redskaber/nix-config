# @path: ~/projects/configs/nix-config/nixos/core/srv/security/ssh.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::security::ssh


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  # SSH
  services.openssh = {
    enable = true;
    settings = {
      # Opinionated: forbid root login through SSH.
      PermitRootLogin = "no";
      # Opinionated: use keys only.
      # Remove if you want to SSH using passwords
      PasswordAuthentication = false;

    };
  };


}


