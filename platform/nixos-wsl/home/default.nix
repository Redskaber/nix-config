# @path: ~/projects/configs/nix-config/platform/nixos-wsl/home/default.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: platform::nixos-wsl::home — the NixOS-WSL home door (T7.1, grammar v4)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# THE home door of platform/nixos-wsl — a deliberately THIN wrapper
# (directory grammar v4, platform-major, domain-explicit):
# mkHomeSystem imports platform/<tag>/home and lands here, and the
# door reuses the nixos user-domain door wholesale. Reading the
# sibling system door (../system/default.nix) tells you the form:
# nixos-wsl IS nixos plus the WSL interpreter, on both domains —
# the schema speaking again, not duplication debt.
#
# Division of labor (the same single-owner rule the system door
# documents):
#
#   platform/nixos/home            OWNS the nixos user-domain
#                                  payload (HM base facts + the
#                                  cross-platform library imports).
#   home/core/base/wsl.nix         OWNS the WSL user-space interop
#                                  (caps.wsl-gated — the standalone
#                                  platform/wsl gets it from the
#                                  same one place).
#   hosts/nixos-wsl/               carries the host's policy — no
#                                  machine facts, same reasoning as
#                                  the system door.
#
# The arch axis is NOT modelled (grammar v4): the x86_64-linux row
# that used to carry the wrapper is retired — every arch of the
# platform walks the ONE same pipeline, and the arch differences
# are absorbed at the nixpkgs layer by the emitter's per-host pkgs
# handle. NOT the platform/wsl door's business: genericLinux
# targets and nixGL are "non-NixOS Linux" facts, and this host runs
# NixOS.
#
# Fork-on-demand: the day the nixos-wsl user domain needs a fact of
# its own, this door grows it here — the wrapper is the seam.
{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/home
  ];
}
