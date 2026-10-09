# @path: ~/projects/configs/nix-config/platform/nixos/core/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::core::default

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
    ./base
    ./drive
    ./exp
    ./sec
    ./srv
  ];

}
