# @path: ~/projects/configs/nix-config/platform/nixos/system/default.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: platform::nixos::system — the NixOS system door (grammar v4)
# @directory: https://search.nixos.org/options
#
# THE system door of platform/nixos — entry and dispatch for the
# system domain (directory grammar v4, platform-major,
# domain-explicit): every platform tag owns a directory, and
# inside it exactly two reserved domain names — system/ and home/
# — each with its own default.nix door. Both domains hold
# SYMMETRIC addresses (mkNixosSystem imports platform/<tag>/system,
# mkHomeSystem imports platform/<tag>/home — the same one-word
# shape on both sides; the dispatch layer projects the tag onto
# the filesystem and never compares it, T4.0).
#
# THIS file: registers the system subsystems (imports = the module
# registry — core/ dm/ wm/ grow free around this door), pulls host
# facts from hosts/${shared.hostName}, pins nixpkgs. The arch axis
# is NOT modelled here or anywhere on disk — all arches of the
# platform walk this one pipeline, and arch differences are
# absorbed at the nixpkgs layer (the emitters' `system` parameter
# and runtime.nix's per-host pkgs synthesis).
#
# Home-manager on NixOS hosts is NOT mounted here — nixos hosts
# keep TWO live doors ON PURPOSE (the system closure AND
# homeConfigurations.<user>@<host>: HM standalone switches in
# seconds and rolls back independently of the system generation),
# so the user domain lives behind its own symmetric door at
# ../home. Two doors, two universes — zero option-existence
# sniffing (a one-file-two-domains trick would need exactly that
# sniffing and is forbidden by the no-if-else rule).
#
# File presence IS the capability declaration — the caps table
# (lib/shared/lang/enum.nix) projected onto the filesystem:
# listing platform/<tag>/ reads off the platform's shape (system/
# present IFF the platform has a system form; linux/wsl own no
# system/ directory at all) before reading a line of code.

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
    # nixos base core configuration
    ./core
    # window manager
    ./wm
    # display manager
    ./dm
    # host-specific config (hardware.nix + overrides)
    ../../../hosts/${shared.hostName}
  ];

  # used user custom inxpkgs
  nixpkgs = shared.nixpkgs;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  system.stateVersion = shared.version.value.stateVersion;

}
