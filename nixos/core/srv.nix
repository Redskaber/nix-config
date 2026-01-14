# @path: ~/projects/configs/nix-config/nixos/core/srv.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv


{
  inputs,
  config,
  lib,
  pkgs,
  ...
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
      # PasswordAuthentication = false;
    };
  };

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us,cn";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";
  # Enable CUPS to print documents.
  # services.printing.enable = true;
  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

}


