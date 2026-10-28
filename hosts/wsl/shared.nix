# @path: ~/projects/configs/nix-config/hosts/wsl/shared.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: hosts::wsl::shared — third-machine policy (host layer)
#
# The WSL host: a Windows-side distro whose user environment this
# flake owns through standalone home-manager (platform/wsl).
#
# With the three-layer chain (fleet → role → host) this file
# shrank to its class key alone: platform = wsl routes this host
# OUT of nixosConfigurations (it is not a NixOS machine) and INTO
# homeConfigurations."kilig@wsl" + the platform/wsl
# specialisation. The `console` role (the fleet registry row)
# supplies the rest: no windowing stack, the amd Null-Object
# drive, lean sets, no app grab-bag trees, minimal services.
#
# P1.5 note: the minimal service profile is now an explicit part
# of the console role — previously this host inherited
# dev-on-demand from the pre-role baseline and silently installed
# four databases inside a WSL distro (the inheritance-bias defect
# the role layer was designed to remove).

{ shared, inputs, ... }:
{
  # Class key: this host is WSL, not NixOS.
  platform = shared.enum.platform.wsl;
}
