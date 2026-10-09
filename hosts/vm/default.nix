# @path: ~/projects/configs/nix-config/hosts/vm/default.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: hosts::vm — virtual machine hardware profile
#
# Eval-level second machine (T2.5): this host exists to prove that one
# flake evaluates two machines from two different policy files (see
# hosts/vm/shared.nix). No machine fingerprints here — a QEMU guest
# has no discrete GPU and no host-specific bus topology. Boot-level
# validation runs under KVM in the CI vm-tests stage; this sandbox
# has no /dev/kvm, so acceptance here is evaluation depth (toplevel
# derivation + policy discriminators verified).

{ ... }:

{
  # What nixos-generate-config would emit for this (virtual) machine.
  nixpkgs.hostPlatform = "x86_64-linux";
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  # QEMU guest agent for the CI VM stages.
  services.qemuGuest.enable = true;
}
