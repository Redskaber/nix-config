# @path: ~/projects/configs/nix-config/nixos/configuration.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description:
# - Edit this configuration file to define what should be installed on your system.
# - Help is available in the configuration.nix(5) man page,
# - on https://search.nixos.org/options and in the NixOS manual (`nixos-help`).


{ inputs
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
    # (move -> boot): ./hardware-configuration.nix
    # ./core/drive

    # nixos base core configuration
    ./core/bluetooth.nix
    ./core/boot.nix
    ./core/compat.nix
    ./core/hardware.nix
    ./core/i18n.nix
    ./core/memory.nix
    ./core/network.nix
    ./core/nix.nix
    ./core/portal.nix
    ./core/sound.nix
    ./core/steam.nix              # Optional
    ./core/systemd.nix
    ./core/user.nix
    ./core/virtual.nix            # Optional

    # security
    ./core/security/pam.nix
    ./core/security/polkit.nix
    ./core/security/secret/cmd/age.nix
    ./core/security/secret/cmd/sops.nix
    ./core/security/secret/cmd/ssh-to-age.nix
    ./core/security/secret/config.nix

    # srv
    ./core/srv/db/mongodb.nix     # Optional
    ./core/srv/db/mysql.nix       # Optional
    ./core/srv/db/postgresql.nix  # Optional
    ./core/srv/db/redis.nix       # Optional
    ./core/srv/desktop/file-manage.nix
    ./core/srv/desktop/flatpak.nix
    ./core/srv/hardware/bluetooth.nix
    ./core/srv/hardware/firmware.nix
    ./core/srv/hardware/power.nix
    ./core/srv/hardware/printing.nix
    ./core/srv/hardware/storage.nix
    ./core/srv/log/logrotate.nix  # Optional
    ./core/srv/security/keyring.nix
    ./core/srv/security/ssh.nix

    # window manager
    # ./wm/gnome
    ./wm/hyprland

  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      inputs.self.overlays.additions
      inputs.self.overlays.modifications
      inputs.self.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };


  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    curl git vim wget
    # sound
      # pamixer
      # pavucontrol
    # bluetooth
      # overskride
    # proxy
      # clash-verge-rev
  ];


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  system.stateVersion = "25.11"; # Did you read the comment?

}

