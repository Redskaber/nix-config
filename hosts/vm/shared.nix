# @path: ~/projects/configs/nix-config/hosts/vm/shared.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: hosts::vm::shared — second-machine policy overrides
#
# The second machine of the multi-host design (T2.3/T2.5): a virtual
# host used to prove the host-scoped policy chain end-to-end at
# evaluation depth. Keys here replace their base shared.nix
# counterparts WHOLESALE (shallow `//` merge — see
# lib/shared/default.nix); hostName is force-aligned to "vm" by the
# loader, which is what routes nixos/… to ../hosts/vm.

{ shared, inputs, ... }:
{
  # Console machine (T7.2, debt #6): a server-form VM runs no
  # compositor and greets no login screen — wm/dm flip to the
  # Null-Object rows, and the closure stops carrying the desktop
  # stack it never started (hyprland + ly + their pull rode the
  # evaluation-level host since T2.3). The base policy's defaults
  # stay with the base host: this is a host override, not a policy
  # change — the same wholesale-flip grammar hosts/wsl and
  # hosts/nixos-wsl use for their console shapes.
  window-manager = shared.enum.window-manager.none;
  display-manager = shared.enum.display-manager.none;

  # Virtual display adapter — no NVIDIA/Prime on a QEMU guest.
  drive = shared.enum.drive-group.amd;

  # Server-flavoured service profile: postgresql only, autostarted.
  service-profile = shared.enum.service-profile.server-pg-only;

  # Lean application sets for a maintenance-oriented machine.
  editor-set = shared.enum.editor-set.minimal;
  terminal-set = shared.enum.terminal-set.kitty-only;
  browser-set = shared.enum.browser-set.chrome-qute;
  # No app grab-bag trees at all (T5.10): a maintenance VM wants its
  # editors/browsers/terminals and the sys toolbelt, nothing else —
  # pre-T5.10 it merged (and installed) the full desktop app universe.
  app-set = shared.enum.app-set.none;
}
