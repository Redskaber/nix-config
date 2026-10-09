# @path: ~/projects/configs/nix-config/home/wm/none/default.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: home::wm::none::default
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# Null-Object window-manager target (T3.1/T3.2): platforms without a
# Linux windowing stack (wsl console host, macOS Aqua) route here via
# shared.window-manager.tag = "none". The module intentionally provides
# NOTHING — its existence is what lets platform/<tag>/x86_64-*.nix keep
# the unconditional `imports = [ ../../home/wm ]` line, so the platform
# tree stays uniform (router pattern: dispatch happens at the edge).

{ ... }:
{
  # Deliberately empty. Consuming code must gate on the resolved
  # capability bit (shared.window-manager.value.desktop-session, T4.0)
  # when it needs a real stack — never on raw tag strings.
  imports = [ ];
}
