# @path: ~/projects/configs/nix-config/platform/nixos-wsl/home/x86_64-linux.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: platform::nixos-wsl::home::x86_64-linux — HM payload row (T7.1)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# The x86_64-linux arch row of platform/nixos-wsl' user domain
# (grammar v3: arch rows live INSIDE home/, next to the HM customs).
#
# A one-line re-export, and that IS the statement: the nixos-wsl
# form's user domain is the nixos user domain — a NixOS-WSL host
# runs the full NixOS userland (own mesa/WSLg stack, own systemd),
# so it consumes the same HM payload the bare-metal nixos hosts do.
# What differs is WSL user-space interop (wslview, WSLENV), and
# that arrives through the SHARED home tree — home/core/base/
# wsl.nix, gated on shared.caps.wsl — so standalone-wsl and
# nixos-wsl hosts read it from one place instead of two copies
# drifting. NOT the platform/wsl row's business: genericLinux
# targets and nixGL are "non-NixOS Linux" facts, and this host
# runs NixOS.
#
# Fork-on-demand: the day the nixos-wsl user domain needs a fact of
# its own, this row grows it here — the wrapper is the seam.

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
    ../../nixos/home/x86_64-linux.nix
  ];
}
