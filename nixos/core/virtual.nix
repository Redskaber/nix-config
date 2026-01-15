# @path: ~/projects/configs/nix-config/nixos/core/virtual.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::virtual


{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  # # Add user to libvirtd group
  # users.users.<username>.extraGroups = [ "libvirtd" ];
  #
  # # Install necessary packages
  # environment.systemPackages = with pkgs; [
  #   virt-manager
  #   virt-viewer
  #   spice
  #   spice-gtk
  #   spice-protocol
  #   virtio-win
  #   win-spice
  #   adwaita-icon-theme
  # ];
  #
  # # Manage the virtualisation services
  # virtualisation = {
  #   libvirtd = {
  #     enable = true;
  #     qemu = {
  #       swtpm.enable = true;
  #     };
  #   };
  #   spiceUSBRedirection.enable = true;
  # };
  # services.spice-vdagentd.enable = true;
  #
  # # Virtualization / Containers
  # virtualisation.libvirtd.enable = false;
  # virtualisation.podman = {
  #   enable = false;
  #   dockerCompat = false;
  #   defaultNetwork.settings.dns_enabled = false;
  # };

}


