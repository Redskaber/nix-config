# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/desktop/flatpak.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: platform::nixos::core::srv::desktop::flatpak

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  # Desktop-session service (T7.2): Flatpak distributes desktop apps
  # and its nixpkgs module ASSERTS xdg.portal.enable — portal
  # mediation is desktop-session-scoped (see core/base/portal.nix's
  # gate), so the two must answer the SAME capability bit. The gate
  # keeps console forms (vm server shape, the nixos-wsl WSL form)
  # free of the flatpak stack they were silently carrying; desktop
  # hosts are untouched.
  config = lib.mkIf shared.window-manager.value.desktop-session {
    services = {
      # Flatpak app support
      flatpak.enable = true;
    };
  };
}
