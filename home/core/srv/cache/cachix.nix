# @path: ~/projects/configs/nix-config/home/core/srv/cache/cachix.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: home::core::srv::cache::cachix

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with shared.pkgs; [
    cachix
  ];

}
