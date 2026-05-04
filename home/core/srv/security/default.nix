# @path: ~/projects/configs/nix-config/home/core/srv/security/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::srv::security::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./gnupg.nix
  ];

}


