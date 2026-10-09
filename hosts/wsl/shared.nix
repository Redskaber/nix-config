# @path: ~/projects/configs/nix-config/hosts/wsl/shared.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: hosts::wsl::shared — third-machine policy overrides (T3.1)
#
# The WSL host of the multi-host design: a Windows-side distro whose
# user environment this flake owns through standalone home-manager
# (platform/wsl). Keys here replace their base shared.nix counterparts
# WHOLESALE (shallow `//` merge — see lib/shared/default.nix).
#
# Class-defining override: platform.tag = "wsl". The flake-level host
# dispatch (flake.nix T3.1/T3.2) routes this host OUT of
# nixosConfigurations (it is not a NixOS machine) and INTO
# homeConfigurations."kilig@wsl" + the platform/wsl specialisation.

{ shared, inputs, ... }:
{
  # Class flip: this host is WSL, not NixOS.
  platform = shared.enum.platform.wsl;

  # Console-oriented machine: no windowing stack (Null-Object wm).
  window-manager = shared.enum.window-manager.none;

  # No NVIDIA/Prime inside the WSL kernel interface.
  drive = shared.enum.drive-group.amd;

  # Maintenance-shaped sets: lean editors/terminals, no desktop apps.
  editor-set = shared.enum.editor-set.minimal;
  terminal-set = shared.enum.terminal-set.kitty-only;
  browser-set = shared.enum.browser-set.cli-only;
  # Console machine (T5.10): the set-routed triad only — this host's
  # own comment said "no desktop apps" since T3.1, but the app tree
  # was eager until now (prismlauncher/wps/blender rode the closure).
  app-set = shared.enum.app-set.none;
}
