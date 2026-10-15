# @path: ~/projects/configs/nix-config/platform/nixos/system/wm/none/default.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: platform::nixos::wm::none — Null-Object window manager
# @directory: https://search.nixos.org/options
#
# The "no window manager" row on the SYSTEM tree (the home tree
# already routes home/wm/none). The nixos-wsl form selects it (a
# WSL console host runs no compositor): like dm/none, deliberately
# empty — existence keeps platform/nixos/system/wm/default.nix
# unconditional.

{ ... }:
{
  # Deliberately empty. Consumers gate on the resolved capability
  # bit (shared.window-manager.value.desktop-session) — never on
  # raw tag strings.
  imports = [ ];
}
