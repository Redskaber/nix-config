# @path: ~/projects/configs/nix-config/hosts/vm/shared.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: hosts::vm::shared — second-machine policy overrides
#
# The second machine of the multi-host design: a virtual
# host used to prove the host-scoped policy chain end-to-end at
# evaluation depth. Keys here replace their base shared.nix
# counterparts WHOLESALE (shallow `//` merge — see
# lib/shared/default.nix); hostName is force-aligned to "vm" by the
# loader, which is what routes nixos/… to ../hosts/vm.

{ shared, inputs, ... }:
{
  # Console machine (debt #6): a server-form VM runs no compositor
  # and greets no login screen — wm/dm flip to the Null-Object rows
  # and the closure stops carrying the desktop stack. The base
  # policy's defaults stay with the base host: a host override, not
  # a policy change (the same wholesale-flip grammar the other
  # console hosts use).
  window-manager = shared.enum.window-manager.none;
  display-manager = shared.enum.display-manager.none;

  # Debt #9 semantic half — pre-ruled flip, staged
  # (docs/guides/sound-adjudication.md §A): the declared facter
  # report carries no audio device and the machine story is
  # server-form, so the pre-ruling is the Null-Object row. Uncomment
  # AFTER `just sound-audit` confirms on the booted machine (the
  # whole stack — pipewire + wireplumber + rtkit + mixers —
  # subtracts with it):
  # sound = shared.enum.sound.none;

  # Virtual display adapter — no NVIDIA/Prime on a QEMU guest.
  drive = shared.enum.drive-group.amd;

  # Server-flavoured service profile: postgresql only, autostarted.
  service-profile = shared.enum.service-profile.server-pg-only;

  # Lean application sets for a maintenance-oriented machine.
  editor-set = shared.enum.editor-set.minimal;
  terminal-set = shared.enum.terminal-set.kitty-only;
  browser-set = shared.enum.browser-set.chrome-qute;
  # No app grab-bag trees at all: a maintenance VM wants its
  # editors/browsers/terminals and the sys toolbelt, nothing else.
  app-set = shared.enum.app-set.none;
}
