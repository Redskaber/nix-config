# @path: ~/projects/configs/nix-config/platform/nixos/default.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: platform::nixos::default — the NixOS system customs (T5.11)
# @directory: https://search.nixos.org/options
#
# THE system-domain customs of platform/nixos. Directory grammar v3 —
# directory-as-domain (T5.11): a platform directory splits its two
# option universes by LEVEL, and every file evaluates in exactly ONE
# of them:
#
#   top level      the SYSTEM domain. default.nix (this file) is the
#                  system door — imported by the system emitters
#                  (mkNixosSystem / mkDarwinSystem); subsystem
#                  directories (core/ dm/ wm/…) grow free around it.
#                  Present IFF the platform has a system form; absent
#                  on linux/wsl (standalone-only platforms — no system
#                  emitter ever asks for them).
#   home/          THE user domain — the one reserved top-level name.
#                  home/default.nix is the HOME door — imported by
#                  mkHomeSystem (the standalone-HM emitter); present
#                  IFF the platform keeps a live homeConfigurations
#                  door; absent on darwin (HM rides inside the
#                  system closure in module mode — the T5.8 fold).
#                  home/<arch>.nix are the HM payload rows — the arch
#                  axis, which exists ONLY in the user domain (the
#                  target double: the platform axis picks the
#                  directory, the arch axis picks the row).
#
# File presence IS the capability declaration — the caps table
# (lib/shared/lang/enum.nix) projected onto the filesystem: listing
# platform/<tag>/ tells you the platform's shape before reading a
# line of code, and every path has exactly one meaning (top level
# = system, home/ = user).
#
# THIS file (the nixos system customs): registers the system
# subsystems (imports = the module registry), pulls host facts from
# hosts/${shared.hostName}, pins nixpkgs. Home-manager on NixOS hosts
# is NOT mounted here — nixos hosts keep TWO live doors ON PURPOSE
# (the system closure AND homeConfigurations.<user>@<host>: HM
# standalone switches in seconds and rolls back independently of the
# system generation), so the HM customs lives one level down in
# ./home/default.nix. Two doors, two universes, two levels — zero
# option-existence sniffing (a one-file-two-domains trick would need
# exactly that sniffing and is forbidden by the no-if-else rule).

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
    ../../hosts/${shared.hostName}
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
