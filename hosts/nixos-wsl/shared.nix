# @path: ~/projects/configs/nix-config/hosts/nixos-wsl/shared.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: hosts::nixos-wsl::shared — fifth-host policy overrides (T7.1)
#
# The NixOS-WSL host of the multi-host design: a Windows-hosted WSL2
# distro whose system AND user layers this flake owns. Keys here
# replace their base shared.nix counterparts WHOLESALE (shallow `//`
# merge — see lib/shared/default.nix).
#
# Class-defining override: platform.tag = "nixos-wsl" — the fifth
# platform row (T7.1). The dispatch layer routes this host INTO
# nixosConfigurations (caps.nixos-system) through the
# platform/nixos-wsl/ customs (nixos tree + the NixOS-WSL
# interpreter), AND into homeConfigurations."kilig@nixos-wsl"
# (both doors live, the nixos policy). The sibling hosts/wsl stays
# the other WSL shape: system layer unowned, standalone HM only.
#
# The shape mirrors hosts/wsl (T3.1's console machine): a WSL host
# is console-shaped — window-manager none, display-manager none
# (the T7.1 Null-Object row), lean sets. What differs from
# hosts/wsl is only the platform flip: this distro IS the NixOS.

{ shared, inputs, ... }:
{
  # Class flip: this host is NixOS-WSL — the fifth system form.
  platform = shared.enum.platform.nixos-wsl;

  # Console-oriented machine: no windowing stack (Null-Object wm +
  # the T7.1 Null-Object dm row).
  window-manager = shared.enum.window-manager.none;
  display-manager = shared.enum.display-manager.none;

  # No NVIDIA/Prime inside the WSL kernel interface.
  drive = shared.enum.drive-group.amd;

  # Maintenance-shaped sets: lean editors/terminals, no desktop apps
  # (mirrors hosts/wsl — same console shape).
  editor-set = shared.enum.editor-set.minimal;
  terminal-set = shared.enum.terminal-set.kitty-only;
  browser-set = shared.enum.browser-set.cli-only;
  app-set = shared.enum.app-set.none;
}
