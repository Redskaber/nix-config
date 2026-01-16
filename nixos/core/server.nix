# @path: ~/projects/configs/nix-config/nixos/core/server.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::server


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  # SSH
  services.openssh = {
    enable = true;
    settings = {
      # Opinionated: forbid root login through SSH.
      PermitRootLogin = "no";
      # Opinionated: use keys only.
      # Remove if you want to SSH using passwords
      PasswordAuthentication = false;

    };
  };

  # Enable CUPS to print documents.
  # services.printing.enable = true;
  # Enable touchpad support (enabled default in most desktopManager).

  services = {
    # No-server disable
    smartd = {
      enable = false;
      autodetect = true;
    };
    # SSD optimite
    fstrim = {
      enable = true;
      interval = "weekly";
    };
    # Flatpak app support
    flatpak.enable = true;
    # Input, bluetooth
    libinput.enable = true;
    blueman.enable = true;
    # Firmware update and power manager
    fwupd.enable = true;
    upower.enable = true;
    # Preview and remote support
    gvfs.enable = true;
    tumbler.enable = true;

    gnome.gnome-keyring.enable = true;
  };
}


