# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/log/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::core::srv::log::default

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
    ./logrotate.nix
  ];

}
