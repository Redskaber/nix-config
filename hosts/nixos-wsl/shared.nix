# @path: ~/projects/configs/nix-config/hosts/nixos-wsl/shared.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: hosts::nixos-wsl::shared — fifth-host policy (host layer)
#
# The NixOS-WSL host: a Windows-hosted WSL2 distro whose system AND
# user layers this flake owns. The class key routes this host INTO
# nixosConfigurations (caps.nixos-system) through the
# platform/nixos-wsl/ customs (system/ domain: nixos tree + the
# NixOS-WSL interpreter), AND into
# homeConfigurations."kilig@nixos-wsl" (both doors live, the nixos
# policy). The sibling hosts/wsl stays the other WSL shape: system
# layer unowned, standalone HM only.
#
# With the three-layer chain (fleet → role → host) this file
# shrank to its class key alone — the `console` role (the fleet
# registry row) supplies the rest: no windowing stack, the amd
# Null-Object drive, lean sets, no app grab-bag trees, minimal
# services (P1.5: the explicit minimal profile replaces the
# dev-on-demand inheritance bias of the pre-role baseline).
#
# Debt #9 (docs/guides/sound-adjudication.md §B): WSLg's audio
# mediation runs in the Windows-side system distro, so the
# pre-ruling is the Null-Object row — the flip lands in the
# console-family role rows (enum.nix) after `just sound-audit`
# confirms inside the booted distro (from a WSLg terminal, not
# over SSH).

{ shared, inputs, ... }:
{
  # Class key: this host is NixOS-WSL.
  platform = shared.enum.platform.nixos-wsl;
}
