# @path: ~/projects/configs/nix-config/home/core/srv/default.nix
# @author: redskaber
# @datetime: 2026-10-13
# @description: home::core::srv::default

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{

  imports = [
    ./cache
    ./db
    ./notify
    ./security
  ];

}
