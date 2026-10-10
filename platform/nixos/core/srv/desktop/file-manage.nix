# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/desktop/file-manage.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::srv::desktop::file-manage

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{

  services = {
    # Preview and remote support
    gvfs.enable = true;
    tumbler.enable = true;
  };

}
