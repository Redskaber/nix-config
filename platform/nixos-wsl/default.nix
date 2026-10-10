# @path: ~/projects/configs/nix-config/platform/nixos-wsl/default.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: platform::nixos-wsl::default — the NixOS-WSL system customs (T7.1)
# @directory: https://github.com/nix-community/NixOS-WSL
#
# THE system-domain customs of platform/nixos-wsl — the fifth system
# form (T7.1): a NixOS system layer hosted inside a WSL2 distro,
# running under the Windows host's kernel.
#
# This door is deliberately THIN, and reading it tells you the whole
# form definition: the nixos-wsl form IS the nixos customs plus the
# NixOS-WSL interpreter. The import of ../nixos reuses the ENTIRE
# bare-metal customs tree (core/, dm/, wm/, the hosts/<h>/ routing,
# stateVersion, nixpkgs pinning) — that reuse is not duplication
# debt but the schema speaking: the fifth platform row answers every
# capability cell exactly like `nixos` except `wsl = true`, so its
# customs are the nixos customs plus exactly one interpreter.
#
# Division of labor (ownership boundary, single-owner rule):
#
#   inputs.nixos-wsl.nixosModules.default OWNS the WSL surface —
#     wsl.conf generation, systemd hosting, interop + binfmt,
#     the boot/kernel/loader subtraction (WSL supplies its own).
#     Hand-rolled duplicates of any of that lived in
#     platform/nixos/core/base/wsl.nix before T7.1 and were removed.
#   platform/nixos/core/base/wsl.nix keeps ONLY this repo's deltas
#     the upstream module does not ship (the chrony clock-drift
#     guard), gated on shared.caps.wsl.
#   hosts/nixos-wsl/ carries the host's data — and deliberately
#     NOTHING machine-factual: no facter.json (the hardware is the
#     Windows host's), no disk.nix (the rootfs is a Windows-managed
#     VHDX provisioned by wsl --import, not by the OS — disko is
#     semantically inapplicable and stays inert by absence), no
#     persist.nix (impermanence on a WSL root buys nothing; stays
#     inert by absence).
#
# Both doors stay live, the nixos policy: the system closure here,
# and homeConfigurations.<user>@<host> through ./home/ — HM standalone
# switches in seconds and rolls back independently of the system
# generation, exactly like the bare-metal nixos hosts. The HM payload
# row (./home/x86_64-linux.nix) is the nixos user-domain row; the
# WSL user-space specialisation rides in the SHARED home tree
# (home/core/base/wsl.nix, caps.wsl-gated) so every wsl-capable
# host — standalone or nixos-wsl — gets it from one place.

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    # The nixos customs — the entire bare-metal system tree, reused
    # (core/ dm/ wm/ + hosts/${shared.hostName} + stateVersion +
    # nixpkgs pinning all arrive through this one line).
    ../nixos

    # The WSL interpreter — upstream owns the WSL surface.
    inputs.nixos-wsl.nixosModules.default
  ];

  # The form's enabling facts. defaultUser is the distro's login
  # user (the upstream module creates it, uid 1000, wheel).
  wsl.enable = true;
  wsl.defaultUser = shared.user.username;

  # The form's boot subtraction, completed: the upstream interpreter
  # plain-assigns boot.loader.grub.enable = false and swaps
  # system.build.installBootLoader for a no-op, but it deliberately
  # does NOT touch systemd-boot — a distro that wants it could (in
  # theory) boot one. This form does not: the nixos base's
  # mkDefault true would keep the systemd-boot module active and its
  # installer then collides with the interpreter's installBootLoader.
  # Plain false wins over the base's mkDefault — that priority spread
  # IS the design (base declares defaults, forms subtract).
  boot.loader.systemd-boot.enable = false;
}
