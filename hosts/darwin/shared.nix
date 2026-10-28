# @path: ~/projects/configs/nix-config/hosts/darwin/shared.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: hosts::darwin::shared — darwin host policy (host layer)
#
# The darwin host: policy-declared as platform.tag = "darwin",
# which the flake dispatch routes into darwinConfigurations
# (nix-darwin + home-manager module mode). The class flip ALSO
# retargets the runtime pkgs instance — arch.tag is what
# lib/shared/runtime imports nixpkgs with, so declaring it here
# gives this host an aarch64-darwin package set without touching
# the loader.
#
# With the three-layer chain (fleet → role → host) this file
# carries exactly what ONLY this machine says about itself: its
# platform class and its arch. The `laptop` role (the fleet
# registry row) supplies the form: the wm Null-Object (Aqua owns
# the compositor), lean terminal-shaped sets, the cross-platform
# document/reading/re app trees, minimal services.

{ shared, inputs, ... }:
{
  # Class key: this host is a darwin machine.
  platform = shared.enum.platform.darwin;

  # Apple Silicon — retargets this host's pkgs instance.
  arch = shared.enum.arch.aarch64-darwin;
}
