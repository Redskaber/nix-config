# @path: ~/projects/configs/nix-config/hosts/nixos-wsl/shared.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: hosts::nixos-wsl::shared — fifth-host policy overrides
#
# The NixOS-WSL host: a Windows-hosted WSL2 distro whose system AND
# user layers this flake owns. Keys here replace their base shared.nix
# counterparts WHOLESALE (shallow `//` merge — see
# lib/shared/default.nix).
#
# Class-defining override: platform.tag = "nixos-wsl". The dispatch
# layer routes this host INTO nixosConfigurations (caps.nixos-system)
# through the platform/nixos-wsl/ customs (system/ domain: nixos
# tree + the NixOS-WSL interpreter), AND into
# homeConfigurations."kilig@nixos-wsl" (both doors live, the nixos
# policy). The sibling hosts/wsl stays the other WSL shape: system
# layer unowned, standalone HM only. A WSL host is console-shaped
# either way — what differs is only the platform flip: this distro
# IS the NixOS.

{ shared, inputs, ... }:
{
  # Class flip: this host is NixOS-WSL.
  platform = shared.enum.platform.nixos-wsl;

  # Console-oriented machine: no windowing stack (Null-Object wm/dm).
  window-manager = shared.enum.window-manager.none;
  display-manager = shared.enum.display-manager.none;

  # Debt #9 semantic half — pre-ruled flip, staged
  # (docs/guides/sound-adjudication.md §B): WSLg's audio mediation
  # runs in the Windows-side system distro (socket projected,
  # PULSE_SERVER preconfigured, no audio hardware in the user
  # distro), so the pre-ruling is the Null-Object row. Uncomment
  # AFTER `just sound-audit` confirms inside the booted distro (from
  # a WSLg terminal, not over SSH):
  # sound = shared.enum.sound.none;

  # No NVIDIA/Prime inside the WSL kernel interface.
  drive = shared.enum.drive-group.amd;

  # Maintenance-shaped sets: lean editors/terminals, no desktop apps.
  editor-set = shared.enum.editor-set.minimal;
  terminal-set = shared.enum.terminal-set.kitty-only;
  browser-set = shared.enum.browser-set.cli-only;
  app-set = shared.enum.app-set.none;
}
