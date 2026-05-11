# @path: ~/projects/configs/nix-config/nixos/core/srv/security/wrappers/default.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nixos::core::srv::security::wrappers::default


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    ./dumpkeys.nix
    ./gdb.nix
  ];


}


