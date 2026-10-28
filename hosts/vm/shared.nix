# @path: ~/projects/configs/nix-config/hosts/vm/shared.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: hosts::vm::shared — second-machine policy (host layer)
#
# The second machine of the multi-host design: a virtual host used
# to prove the host-scoped policy chain end-to-end at evaluation
# depth. With the three-layer chain (fleet → role → host) this file
# shrank to what ONLY this machine says about itself:
#
#   platform    — the class key (a NixOS guest, no longer inherited
#                 from the base policy by accident of history)
#   browser-set — the ONE true specialisation: this maintenance VM
#                 keeps a graphical browser pair, unlike its console
#                 siblings
#
# Everything else arrived with the `server` role (the fleet
# registry row): no compositor, no greeter, the amd Null-Object
# drive, lean sets, no app grab-bag trees, postgresql-only
# services. The host layer still wins over any role key —
# specialisation stays one key away.
#
# Debt #9 (docs/guides/sound-adjudication.md §A): the declared
# facter report carries no audio device and the machine story is
# server-form, so the pre-ruling is the Null-Object row. The flip
# now lands in ONE place — the console-family role rows in
# enum.nix — after `just sound-audit` confirms on the booted
# machine.

{ shared, inputs, ... }:
{
  # Class key: this host is a NixOS machine.
  platform = shared.enum.platform.nixos;

  # The one true specialisation: a maintenance VM that still wants
  # a graphical browser pair (chrome for the odd web console,
  # qutebrowser for the keyboard-driven loop).
  browser-set = shared.enum.browser-set.chrome-qute;
}
