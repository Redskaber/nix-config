# @path: ~/projects/configs/nix-config/nixos/configuration.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description:
# - Edit this configuration file to define what should be installed on your system.
# - Help is available in the configuration.nix(5) man page,
# - on https://search.nixos.org/options and in the NixOS manual (`nixos-help`).


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/nixos):
    # inputs.self.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix
    # Import your generated (nixos-generate-config) hardware configuration
    # nixos base core configuration
    ./core
    # window manager
    ./wm
    # dispaly manager
    ./dm

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

  system.stateVersion = shared.version.value;


}


