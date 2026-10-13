# @path: ~/projects/configs/nix-config/home/core/srv/cache/default.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: home::core::srv::cache::default

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
    ./cachix.nix
  ];

}
