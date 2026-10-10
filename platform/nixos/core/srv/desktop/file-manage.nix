# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/desktop/file-manage.nix
# @author: redskaber
# @datetime: 2026-10-10
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
  # Desktop-session service (T7.2): gvfs (virtual filesystems for
  # desktop file managers) and tumbler (file previews/thumbnails)
  # serve the desktop session — a console host has no file manager
  # to serve. Same capability bit as flatpak.nix next door and
  # core/base/portal.nix: the group's routers stay unconditional,
  # the modules gate on the resolved fact.
  config = lib.mkIf shared.window-manager.value.desktop-session {
    services = {
      # Preview and remote support
      gvfs.enable = true;
      tumbler.enable = true;
    };
  };
}
