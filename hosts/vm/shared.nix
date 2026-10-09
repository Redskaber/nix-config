# @path: ~/projects/configs/nix-config/hosts/vm/shared.nix
# @author: redskaber
# @datetime: 2026-10-08
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
