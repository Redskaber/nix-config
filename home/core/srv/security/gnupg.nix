# @path: ~/projects/configs/nix-config/home/core/srv/security/gnupg.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::srv::security::gnupg


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    gnupg     # PGP signing/encryption, key management
  ];

}


