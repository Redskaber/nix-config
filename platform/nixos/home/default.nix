# @path: ~/projects/configs/nix-config/platform/nixos/home/default.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: platform::nixos::home — the standalone-HM customs (T5.11)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# THE home-domain customs of platform/nixos — the second live door.
# Directory grammar v3 — directory-as-domain (T5.11): a platform
# directory splits its two option universes by LEVEL. The top level
# is the system domain (default.nix + core/ dm/ wm/…); this subtree
# — home/, the one reserved top-level name — IS the user domain.
# mkHomeSystem imports platform/<tag>/home (a directory reference,
# uniform with the two system emitters); the door inside is this
# file, and the arch rows sit next to it as siblings:
#
#   imports = [ ./${shared.arch.tag}.nix ]
#
# The target double, spatially: the platform axis picked this
# directory; the arch axis picks the payload row. The arch axis
# exists ONLY in the user domain (system-level arch differences
# are absorbed by the emitter's `system` parameter at the nixpkgs
# layer) — v2 codified that as a comment; v3 gives it an address.
#
# nixos hosts keep BOTH doors live on purpose — a policy, not a
# residue: the standalone HM closure switches in seconds and rolls
# back independently of the system generation, while the system
# door one level up (../default.nix) owns hardware/services. The
# two option universes never share a FILE (that would need
# option-existence sniffing — config-layer if-else, forbidden) and
# since T5.11 they never even share a LEVEL.
#
# Consumers: mkHomeSystem — ACTIVE, homeConfigurations.<user>@<host>
# for every nixos-system host. darwin's equivalent door is closed by
# grammar (no home/default.nix inside platform/darwin/home/ — HM
# rides in module mode inside the darwin system customs, the T5.8
# fold; the arch rows still live in that subtree, differently
# mounted).
{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./${shared.arch.tag}.nix
  ];

}
