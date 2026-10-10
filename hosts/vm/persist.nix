# @path: ~/projects/configs/nix-config/hosts/vm/persist.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: hosts::vm::persist — the guest's state strategy (impermanence, T5.14)
#
# THE DATA half of the persistence fact pair (interpreter lives
# platform-side in platform/nixos/core/base/impermanence.nix — the
# third fact pair of the hosts/ doctrine, after facter.json T5.12 and
# disk.nix T5.13). Two declarations, no behavior:
#
#   redskaber.impermanence.ephemeral-root.enable
#       the machine FACT that its root is ephemeral — the
#       interpreter derives the btrfs subvolume rollback from the
#       layout in ./disk.nix (assertions connect the two data files);
#
#   environment.persistence."/persistent"
#       the INVENTORY of what survives — the interpreter derives
#       neededForBoot and upstream impermanence turns each entry
#       into an early bind mount.
#
# The set is deliberately minimal — this is the experiment's honest
# starting inventory for a maintenance VM, not a curated desktop
# list (user directories can ride later via the users.<name>
# surface). What it holds:
#
#   /var/log               the journal survives reboots (and can be
#                          read after the ones that went wrong)
#   /var/lib/nixos         NixOS's uid/gid allocation state — losing
#                          it reshuffles file ownership across boots
#   /var/lib/systemd/coredump   crash forensics for the same reason
#   /var/lib/postgresql    the one real service state on this machine
#                          (server-pg-only service profile)
#   /etc/machine-id        file, not directory — journal continuity
#                          and stable DHCP client identity
#
# Everything else on / evaporates at boot. That is the point.

{ ... }:

{
  # The state strategy declaration — the interpreter (platform-side)
  # owns every consequence: the rollback recipe, the neededForBoot
  # contract, the failure modes.
  redskaber.impermanence.ephemeral-root.enable = true;

  # The survival inventory — data only.
  environment.persistence."/persistent" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/postgresql"
    ];
    files = [
      "/etc/machine-id"
    ];
  };
}
