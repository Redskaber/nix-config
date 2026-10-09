# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/desktop/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::core::srv::desktop::default

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
    ./file-manage.nix
    ./flatpak.nix
  ];

}
