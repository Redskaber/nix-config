# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/security/wrappers/default.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: platform::nixos::system::core::srv::security::wrappers::default

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./dumpkeys.nix
    ./gdb.nix
  ];

}
