# @path: ~/projects/configs/nix-config/platform/nixos-wsl/home/default.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: platform::nixos-wsl::home — the standalone-HM customs (T7.1)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# THE home-domain customs of platform/nixos-wsl. Directory grammar
# v3 — directory-as-domain: this subtree IS the user domain of the
# fifth platform; mkHomeSystem imports platform/nixos-wsl/home (a
# directory reference, uniform with every sibling platform), the
# door inside dispatches by arch:
#
#   imports = [ ./${shared.arch.tag}.nix ]
#
# The payload row next to this file reuses the nixos user-domain row
# (the nixos-wsl form's user domain IS the nixos user domain —
# NixOS userland, shared home tree); the WSL user-space bits ride in
# the shared tree, caps.wsl-gated (home/core/base/wsl.nix).

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
    ./${shared.arch.tag}.nix
  ];

}
