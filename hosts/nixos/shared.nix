# @path: ~/projects/configs/nix-config/hosts/nixos/shared.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: hosts::nixos::shared — the base host's own policy file
#
# The first machine of the fleet. Before the three-layer chain
# (fleet → role → host) this host lived ENTIRELY inside the root
# shared.nix — the base policy doubled as "the nixos machine's
# complete configuration", and every other host paid the
# subtraction tax of overriding its form keys away. P0 moved the
# class key here; the form keys moved into the workstation role
# (enum.nix), which this host takes through the fleet registry
# (shared.nix → roles).
#
# What remains is what ONLY this machine can say about itself:
# its platform class. Form stacks come from the role (hyprland,
# ly, dev editor-set, full app-set, dev-on-demand services);
# identity and majority defaults come from the fleet layer.
#
# Keys here replace their layer-chain counterparts (the host layer
# wins the merge — lib/shared/default.nix); `shared.why.<key>`
# reports the winning layer for any key.

{ shared, inputs, ... }:
{
  # Class key: this host is a NixOS machine.
  platform = shared.enum.platform.nixos;
}
