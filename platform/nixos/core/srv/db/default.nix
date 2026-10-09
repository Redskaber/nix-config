# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/db/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::core::srv::db::default

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
    ./mongodb.nix
    ./mysql.nix
    ./postgresql.nix
    ./redis.nix
  ];

}
