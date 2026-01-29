# @path: ~/projects/configs/nix-config/home/core/sys/security.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::sys::security


{ inputs
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


