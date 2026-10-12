# @path: ~/projects/configs/nix-config/tests/lib/shared/orc-guard.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: tests::lib::shared::orc-guard — the orc include-intent guard consumption contract (T30)
# @source: flake.lock (the pinned configuration-orchestrator) × shared.orc (the production handle)
#
# The third tool-library feedback loop closes here, one member after
# the loop it guards: T28 caught the silent failure in the wild (a
# swaync theme chain whose include matched no tree entry — an
# activation that planted nothing while claiming to), T29 fed the
# guard back to orc (paste-ready patch, adopted upstream as 05c658f
# "fail eval when non-empty include selects nothing"), and T30
# consumes it back through the lock. This battery is the WHAT half of
# that consumption (the 97th version contract's shape: the lock
# answers WHERE, this test answers WHAT the pinned orc must carry —
# the silent no-op class is dead, and this is the machine that says
# so on the exact handle the production modules use).
#
# What the contract pins (four assertions, one real FileMap):
#
#   1. guarded     — a non-empty include selecting NOTHING must fail
#                    AT EVAL TIME (tryEval success = false). Pre-guard
#                    orc merged silently (homeFiles = {}, activation
#                    = "" — the T28 failure class). THE contract.
#   2. normal      — a policy whose include matches the tree merges
#                    exactly as before (the guard must be free on the
#                    happy path): the copy policy produces its
#                    activation plant and an EMPTY homeFiles — the
#                    emitter evicts what it plants, the whole output
#                    lives in the activation
#   3. escapeHatch — allowEmpty = true produces the asserted-intended
#                    empty result: homeFiles = {}, activation = ""
#   4. acceptAll   — include = [] keeps the accept-all semantics
#                    (a census, not a filter: non-empty homeFiles)
#
# The FileMap is the REAL swaync-config census — the very tree whose
# missing placeholder started this loop (carrying it since c8818d9)
# — so the normal-path policy below is the fleet's own production
# policy for that site, and the guarded case uses a pattern that
# never exists ("wallust/never-exists.css").
#
# Construction discipline (the version.nix shape): the assertions
# run at CHECK-BUILD time through the runtime-resolved shared.orc —
# the same handle the seven §6 sites call — no mock, no copy. The
# guard's throw reaches WHNF through orc's own `builtins.deepSeq
# allDecisions` return shape (the first T29 draft hid the throw in a
# thunk and a shallow tryEval read false-green; the fix shipped with
# the guard), so tryEval here is honest by construction. The VM is a
# dummy (the contract is an eval-time property).
#
# Mutation check: revert the orc lock to b432296 (pre-guard) →
# assertion 1 goes red (the tryEval SUCCEEDS — the silent class is
# back), the throw names the reconciliation; verified on the real
# eval via --override-input.

{
  inputs,
  shared,
  lib,
  ...
}:
let
  # ── the REAL tool, through the production handle ─────────────────
  orc = shared.orc;

  # the real tree: the swaync-config census (carries wallust/
  # colors-wallust.css since the T28.3 config-repo fix was adopted)
  files = orc.listFilesRecursive inputs.swaync-config "";

  # ── the four assertions, as data ──────────────────────────────────
  normal = orc.mergeHomeFiles files [
    {
      include = [ "wallust/colors-wallust.css" ];
      emitter = "copy";
      destPrefix = ".config/swaync";
    }
  ];

  guarded = builtins.tryEval (
    orc.mergeHomeFiles files [
      {
        include = [ "wallust/never-exists.css" ];
        emitter = "copy";
        destPrefix = ".config/swaync";
      }
    ]
  );

  escaped = orc.mergeHomeFiles files [
    {
      include = [ "wallust/never-exists.css" ];
      emitter = "copy";
      destPrefix = ".config/swaync";
      allowEmpty = true;
    }
  ];

  acceptAll = orc.mergeHomeFiles files [
    {
      include = [ ];
      emitter = "symlink";
      destPrefix = ".config/swaync-census";
    }
  ];

  # ── flat verdict chain: first violation wins ─────────────────────
  violations = lib.filter (v: v != null) [
    (
      if !guarded.success then
        null
      else
        ''
          orc include-intent guard contract violation (T30):
            a non-empty include selecting NOTHING evaluated
            SUCCESSFULLY — the locked orc (flake.lock
            configuration-orchestrator) predates the include-intent
            guard, and the silent no-op activation (the T28 failure
            class) is LIVE again fleet-wide.

            Reconciliation:
              1. bump the input — the guard landed upstream as 05c658f
                 (`nix flake update configuration-orchestrator`)
              2. a local override for development must point at a tree
                 that carries the guard
              3. if orc upstream reverted the guard deliberately, this
                 contract is the tripwire — re-plan the silent-failure
                 defense before removing this member''
    )
    (
      if normal.homeFiles == { } && normal.activation != "" then
        null
      else
        ''
          orc include-intent guard contract violation (T30):
            the normal path is not free: the production policy (copy
            over the placeholder) must produce activation commands and
            an EMPTY homeFiles (the copy emitter evicts its keys — the
            whole plant lives in the activation). Either the guard
            over-fires, or the swaync-config tree restructured (the
            FileMap here is the real census — check the include
            pattern against the tree).''
    )
    (
      if escaped.homeFiles == { } && escaped.activation == "" then
        null
      else
        ''
          orc include-intent guard contract violation (T30):
            allowEmpty = true must produce the asserted-intended empty
            result (homeFiles = {}, activation = "") — the escape hatch
            changed shape. The guard and the opt-out are one contract;
            a hatch that half-merges is worse than none.''
    )
    (
      if acceptAll.homeFiles != { } then
        null
      else
        ''
          orc include-intent guard contract violation (T30):
            include = [] (accept-all) produced an EMPTY homeFiles — the
            census semantics broke, or the FileMap source rotted (the
            tree must stay real for this battery to mean anything).''
    )
  ];

  contractHeld =
    if violations == [ ] then
      "orc include-intent guard contract held: guarded throws, normal merges, escape hatch opt-outs, accept-all accepts — the locked orc carries the T29 guard"
    else
      throw (builtins.head violations);
in
{
  name = "lib_shared_orc_guard";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 300;
  };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("orc: include-intent guard consumption contract — the locked orc must carry the guard the 99th test's failure class fed upstream"):
        # ${contractHeld} — renders only if every assertion held; the
        # machine is a dummy (the contract is an eval-time property).
        machine.succeed("true")
  '';
}
