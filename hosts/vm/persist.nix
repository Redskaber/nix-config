# @path: ~/projects/configs/nix-config/hosts/vm/persist.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: hosts::vm::persist — the guest's state strategy (impermanence)
#
# THE DATA half of the persistence fact pair (interpreter lives
# platform-side in platform/nixos/system/core/base/impermanence.nix).
# Two declarations, no behavior:
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
# The set is deliberately minimal — an honest starting inventory for
# a maintenance VM, not a curated desktop list (user directories can
# ride later via the users.<name> surface): /var/log (journal),
# /var/lib/nixos (uid/gid allocation — losing it reshuffles file
# ownership), /var/lib/systemd/coredump (crash forensics),
# /var/lib/postgresql (the one real service), /etc/machine-id (file,
# not directory — journal continuity and stable DHCP client identity).
# Everything else on / evaporates at boot. That is the point.

{ ... }:

{
  # The state strategy declaration — consequences owned platform-side.
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
