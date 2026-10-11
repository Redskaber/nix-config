# @path: ~/projects/configs/nix-config/hosts/nixos/deploy.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: hosts::nixos::deploy — colmena deployment facts (T20.1)
# @directory: https://colmena.cli.rs/0.5/reference/deployment.html
#
# Machine facts for the deploy face — the disk.nix/persist.nix family
# (coordinates are host facts; the interpreter is lib/shared/targets.nix's
# colmena emitter). File presence IS the declaration "this host carries
# deploy facts"; wholesale-merged OVER the policy defaults there
# (targetUser derives from the policy user — ssh.nix forbids root and
# passwords, so that default never changes here).
#
# What this file does NOT carry, on purpose (facts nobody can verify yet
# are lying facts — write them the day they become true):
#   targetHost   — absent = colmena resolves the node name "nixos"
#                  (mDNS/hosts-file LAN). Set an address when a second
#                  machine lands (debt #8 item 1) or the host moves off
#                  LAN reachability.
#   targetPort   — 22 (ssh.nix default); set only if it ever moves.
#   tags         — none until there is more than one node to group.
{
  # The base machine is where colmena itself runs — the local flavor
  # (`just deploy-local` → colmena apply-local --sudo) needs this opt-in
  # on the node, parity with `nixos-switch` (the T10.2 push-host-boot
  # family: the machine is its own deployment target until a second one
  # exists).
  allowLocalDeployment = true;
}
