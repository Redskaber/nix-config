# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/security/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::core::srv::security::default

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
    ./wrappers

    ./keyring.nix
    ./ptrace.nix
    ./ssh.nix
  ];

}
