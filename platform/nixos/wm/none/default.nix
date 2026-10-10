# @path: ~/projects/configs/nix-config/platform/nixos/wm/none/default.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: platform::nixos::wm::none — Null-Object window manager (T7.1)
# @directory: https://search.nixos.org/options
#
# The "no window manager" row on the SYSTEM tree (T7.1). The enum
# variant has existed since T3.1 (portal none + desktop-session
# false — the home tree already routes home/wm/none), but no nixos-
# class host ever selected it, so the system-side router never needed
# the directory. The nixos-wsl form does (a WSL console host runs no
# compositor), so the row lands: like dm/none, deliberately empty —
# existence keeps platform/nixos/wm/default.nix unconditional.

{ ... }:
{
  # Deliberately empty. Consumers gate on the resolved capability
  # bit (shared.window-manager.value.desktop-session) — never on
  # raw tag strings.
  imports = [ ];
}
