# @path: ~/projects/configs/nix-config/tests/lib/shared/overlays.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: tests::lib::shared::overlays — the overlay locality census (T24.2)
# @source: overlays/default.nix × lib/shared/runtime/default.nix (the loader)
#
# run 38171937689's re-run named the darwin leg's root failure: a
# cutter-2.5.0 drv requiring x86_64-linux inside the aarch64-darwin
# closure. The forensic chain (read from the real tree, not guessed):
# overlays/default.nix's patches defined cutter_patched as
# `shared.upkgs.cutter.overrideAttrs …`, but shared.nix wires every
# host's nixpkgs.overlays through `shared.self.overlays` — the
# FLAKE-LEVEL output, instantiated once with the BASE host's IR
# (targets.base, the x86_64-linux workstation). So the darwin host's
# upkgs.cutter_patched resolved to the base instance's unstable
# import: a linux drv in a macOS home closure. Cache-substitutable
# members (gcc/gdb/rustc — the same class of cross-wiring, had any
# OTHER overlay attr been consumed) masked nothing; cutter_patched's
# unique postPatch made it uncacheable, and the macOS runner named
# it: platform mismatch, root derivation cutter-2.5.0.
#
# The law this census locks: overlays are INSTANCE-LOCAL — what an
# overlay patches is the package set it is APPLIED to (the overlay
# contract; `prev`/`final` are the instance's own fixpoint). The
# lock is a canary substitution: apply patches to a stub instance
# whose touched members are a marked drv, then require every patched
# member to still carry the mark — a member patched from any other
# instance loses it and the census fires, naming the member.
#
# Construction discipline (the deploy.nix precedent): the overlay
# file is imported the way lib/shared/runtime/default.nix loads it,
# and `shared` is passed deliberately — the BASE-bound instance that
# caused the bug — proving the overlay no longer cares which
# binding loads it (binding-independence is the point).
#
# Mutation check: revert cutter_patched to `shared.upkgs.cutter` →
# the canary mark is lost (the member resolves from the base
# instance's real cutter) → the census fires naming cutter_patched;
# stub only openldap → its patched member keeps the mark (prev-local
# by construction), a missing-stub member fails loudly at eval
# instead of testing nothing.

{
  inputs,
  shared,
  pkgs,
  lib,
  ...
}:
let
  # ── the overlays, loaded the way the runtime loads them ───────────
  # (base-bound shared passed on purpose — see the header)
  overlays = import ../../../overlays { shared = shared; };

  # ── the canary instance ───────────────────────────────────────────
  # A marked drv standing in for every member the patches overlay
  # touches; meta.description survives overrideAttrs, so a patched
  # member carries the mark iff it was patched FROM this instance.
  canary = pkgs.runCommand "overlay-locality-canary" {
    meta.description = "INSTANCE-LOCAL-CANARY";
  } "";

  stubSet = {
    cutter = canary;
    openldap = canary;
    xdg-desktop-portal = canary;
  };

  patched = overlays.patches stubSet stubSet;

  # ── the census: every patched member must carry the canary ──────
  members = [
    "cutter_patched"
    "openldap"
    "xdg-desktop-portal"
  ];

  foreignViolations = map (
    m:
    "  ${m}: patched from OUTSIDE the instance it was applied to — the canary mark is gone (this member read a foreign package set, not `prev`)"
  ) (builtins.filter (m: (patched.${m}.meta.description or "") != canary.meta.description) members);

  overlayLocalityVerdict =
    if foreignViolations == [ ] then
      "all ${toString (builtins.length members)} patched members instance-local — the canary mark survived every overrideAttrs (cutter_patched/openldap/xdg-desktop-portal read `prev`, the applied instance's own fixpoint; the base-bound loader that caused run 38171937689's darwin verdict is provably irrelevant now)"
    else
      throw ''
        overlay locality census violations (T24.2):
        ${lib.concatStringsSep "\n" foreignViolations}

        Overlays are instance-local: what an overlay patches is the
        package set it is applied to. A member that reads a foreign
        handle (shared.upkgs, an imported instance, anything that is
        not `prev`/`final`) cross-wires hosts — run 38171937689's
        re-run shipped the base workstation's x86_64-linux cutter
        into the darwin closure that way. See
        tests/lib/shared/overlays.nix's header for the law and the
        mutation checks.'';
in
{
  name = "lib_shared_overlays";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 60;
  };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("overlays: the locality census — every patched member comes from the instance the overlay was applied to, never a foreign handle"):
        # ${overlayLocalityVerdict} — renders only if every member held
        # the canary; the machine itself is a dummy (the law is an
        # eval-time property).
        machine.succeed("true")
  '';
}
