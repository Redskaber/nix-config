# @path: ~/projects/configs/nix-config/tests/lib/shared/lang/version.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: tests::lib::shared::lang::version — the nix-types version contract
# @source: flake.nix (the pinned input) × inputs.nix-types.lib (the consumed library)
#
# The lock answers WHERE, this battery answers WHAT (nix-types
# docs/PATTERNS.md pattern #2, the version contract): flake.nix pins
# nix-types to an audited 40-hex rev, and this test pins the version
# identity that rev is expected to carry. A bump is a TWO-file
# deliberate decision —
#
#   1. flake.nix: nix-types.url = "github:Redskaber/nix-types/<new-rev>"
#      (+ nix flake update nix-types — the lock follows the pin)
#   2. this file: expected = "<new version>"
#
# Either side drifting alone turns the battery red in one line:
#   - bump the pin without the version → this test names the drift
#     (upstream changed identity — the deliberate-decision moment)
#   - bump the version without the pin → same red, opposite direction
#     (a phantom expectation nothing serves)
# Without this contract a stale pin fails three layers downstream as
# "attribute 'version' missing" — the one-line red is the whole point.
#
# Construction discipline (the fn.nix shape): the assertion runs at
# CHECK-BUILD time against the REAL flake input — the same
# inputs.nix-types every lang module consumes — no mock, no copy. The
# VM is a dummy (the contract is an eval-time property).
#
# Mutation check: change expected to any other string → the verdict
# throw names both sides (the lock's rev and the observed version)
# with the two files to reconcile; revert the flake.nix pin alone
# (keep the new expected) → same throw, naming the old rev.

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # ── the REAL consumed library, through the same door everything
  # else reads (lang modules import inputs.nix-types.lib) ──────────
  observed = inputs.nix-types.lib.version or null;
  expected = "3.6.0";

  versionVerdict =
    if observed == expected then
      "nix-types version contract held: inputs.nix-types.lib.version == \"${expected}\" (the lock pins rev ${inputs.nix-types.rev} — WHERE and WHAT agree, the two-file bump discipline intact)"
    else
      throw ''
        nix-types version contract violation (T25.2):
          the lock answers WHERE: inputs.nix-types.rev = ${inputs.nix-types.rev or "<no rev on this input>"}
          this test answers WHAT: expected lib.version == "${expected}"
          observed: ${
            if observed == null then
              "<attribute missing — the pinned rev predates the version identity (pre-3.6.0 nix-types)>"
            else
              "\"${observed}\""
          }

        A nix-types bump is a TWO-file deliberate decision:
          1. flake.nix — nix-types.url = "github:Redskaber/nix-types/<new-rev>"
             then `nix flake update nix-types` (the lock follows the pin)
          2. tests/lib/shared/lang/version.nix — this file's `expected`
        Reconcile the two (see nix-types docs/PATTERNS.md pattern #2:
        rev answers where, version answers what — either side drifting
        alone is a half-decided upgrade).'';
in
{
  name = "lib_shared_lang_version";
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

    with subtest("version: the nix-types version contract — the lock's WHERE and the battery's WHAT agree"):
        # ${versionVerdict} — renders only if the contract held; the
        # machine itself is a dummy (the law is an eval-time property).
        machine.succeed("true")
  '';
}
