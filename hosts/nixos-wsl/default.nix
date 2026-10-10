# @path: ~/projects/configs/nix-config/hosts/nixos-wsl/default.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: hosts::nixos-wsl::default — the fifth host's data (T7.1)
#
# The NixOS-WSL host of the multi-host design (T7.1): a WSL2 distro
# whose SYSTEM layer this flake now owns too — the eval-level second
# system host after vm, exercising the fifth platform row
# end-to-end (policy chain → classification → both emitters).
#
# Deliberately NO machine-fact files, and that absence is the data:
#
#   no facter.json  — the "hardware" is the Windows host's; a WSL
#                     distro reports a fixed virtio-ish machine the
#                     interpreter (NixOS-WSL) already knows how to
#                     host. Nothing to discover.
#   no disk.nix     — the rootfs is a Windows-managed VHDX,
#                     provisioned by `wsl --import` outside the OS;
#                     disko is semantically inapplicable (its
#                     interpreter stays registered and inert).
#   no persist.nix — ephemeral-root buys nothing on a WSL root;
#                     impermanence stays registered and inert.
#
# Runtime wiring on a real machine: build the distro tarball
# (`config.system.build.tarballBuilder`, provided by the NixOS-WSL
# interpreter) and import it — activation/boot-level acceptance is
# the CI vm-tests stage / a Windows host (README known-debt #8's
# environment-gated class).

{ shared, ... }:
{
  # The one machine fact this form HAS (see header: no facter.json —
  # the "hardware" is the Windows host's). The bare-metal hosts set
  # hostPlatform through their hardware facts (facter.json /
  # hardware.nix); the WSL form's equivalent fact is the arch alone.
  nixpkgs.hostPlatform = shared.arch.tag;

  # Deliberately nothing else: this host's machine facts are all
  # negations (see header); everything else arrives via the policy
  # chain (hosts/nixos-wsl/shared.nix) and the platform customs
  # (platform/nixos-wsl/).
}
