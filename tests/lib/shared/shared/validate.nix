# @path: ~/projects/configs/nix-config/tests/lib/shared/shared/validate.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::lib::shared::shared::validate
# @source: lib/shared/shared/validate.nix (Result railway)
#
# T4.1 (Option/Result 类型化错误处理): secret path construction is a
# Result railway over the nix-types ADT. This contract test locks:
#
#   1. the Ok lane — a fixture-tree secret resolves to its .yaml source
#      (front end + resolution pass, against a PROVISIONED tree)
#   2. the Err lane per pass — empty / leading-slash / ".." / empty
#      segment / ".yaml" suffix each die with their own diagnostic
#   3. front-end precedence — "/../x" reports the RELATIVE diagnostic,
#      not the confined one (first failing pass wins, like a compiler
#      front end: lexing errors before resolution errors)
#   4. the resolution pass, provisioned branch — a declared-but-missing
#      secret reports "declared but not provided" (the eval-time
#      diagnostic class; T4.1 strictness is owed once ANY blob exists)
#   5. the boundary — unwrapOrElse throw on an Err throws
#      (tryEval-catchable, same observable discipline as fn.sameSource)
#   6. the runtime-path variant — same front end, mapped onto the
#      /run/secrets constants
#   7. the resolution pass, EMPTY branch — a fresh-clone tree (zero
#      *.yaml under the base) is the lifecycle's ENTRY state: the
#      declared secret resolves Ok (trace + path), not Err — the hard
#      failure moves to sops activation, where it belongs
#
# Fixtures (committed, self-contained — the test no longer couples to
# the live secrets/chipr tree, whose state is a LIFECYCLE property the
# user owns: EMPTY on a fresh clone, provisioned after `just
# secret-set`. Mutating a FIXTURE tree — git mv the yaml out of
# secrets-provisioned, or drop a yaml into secrets-empty — turns the
# corresponding assertions red at eval time, before any VM boots: that
# is exactly the incident class this railway exists to catch.)
#
#   tests/fixtures/secrets-provisioned/nixos/core/base/user/u/password.yaml
#   tests/fixtures/secrets-empty/.gitkeep        (exists, zero *.yaml)

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # ── REAL production imports (no mocks, no copies) ──────────────────
  realConst = import ../../../../lib/shared/shared/const.nix;
  realFn = import ../../../../lib/shared/shared/fn.nix { };
  realValidate = import ../../../../lib/shared/shared/validate.nix {
    inherit inputs;
    fn = realFn;
  };

  inherit (inputs.nix-types.lib) result;

  hasInfix = lib.hasInfix;
  root = ./../../../..; # the repo root, as the flake sees it

  # ── fixture trees (see header) ─────────────────────────────────────
  # base must be ROOT-RELATIVE (fn.sopsFile joins "${self}/${base}/…"):
  #   <root>/tests/fixtures/secrets-provisioned  carries one blob
  #   <root>/tests/fixtures/secrets-empty         exists, zero *.yaml
  provisionedBase = "tests/fixtures/secrets-provisioned";
  emptyBase = "tests/fixtures/secrets-empty";
  presentRel = "nixos/core/base/user/u/password"; # exists in the fixture
  missingRel = "nixos/core/base/user/u/nonexistent"; # well-formed, absent

  # ── Eval-time assertions (fail the check build, not just the VM) ──
  evalAssertions =
    # 1. Ok lane: front end + resolution against the PROVISIONED fixture
    #    tree — the value is exactly what fn.sopsFile interpolates (SSOT).
    assert
      let
        r = realValidate.sopsFileR root provisionedBase presentRel;
      in
      result.isOk r && result.unwrap r == realFn.sopsFile root provisionedBase presentRel;
    # 2. Err lane per pass — each failing shape gets its own sentence.
    assert
      !(builtins.tryEval (result.unwrap (realValidate.relR ""))).success
      && hasInfix "empty" (result.unwrapErr (realValidate.relR ""));
    assert hasInfix "repo-relative" (result.unwrapErr (realValidate.relR "/nixos/core/abs"));
    assert hasInfix "must not contain" (result.unwrapErr (realValidate.relR "nixos/../password"));
    assert hasInfix "empty path segment" (result.unwrapErr (realValidate.relR "nixos//password"));
    assert hasInfix ".yaml" (result.unwrapErr (realValidate.relR "nixos/core/password.yaml"));
    # 3. Front-end precedence: "/../x" is a relative-path offence first
    #    (substring check fires before the ".." scan, and before any
    #    filesystem question is asked).
    assert hasInfix "repo-relative" (result.unwrapErr (realValidate.relR "/../password"));
    # 4. Resolution pass, provisioned branch: the fixture tree carries a
    #    blob, so a well-formed but absent secret reports the
    #    "declared but not provided" class with the resolved path in it.
    assert
      let
        r = realValidate.sopsFileR root provisionedBase missingRel;
      in
      !(result.isOk r)
      && hasInfix "declared but not provided" (result.unwrapErr r)
      && hasInfix "nonexistent.yaml" (result.unwrapErr r);
    # 5. Boundary: the Err value becomes the throw at the edge —
    #    catchable, carrying the diagnostic (sameSource discipline).
    assert
      !(builtins.tryEval (
        result.unwrapOrElse throw (realValidate.sopsFileR root provisionedBase missingRel)
      )).success;
    # 6. Runtime-path variant: the same front end, mapped over the
    #    /run/secrets constants (no filesystem question asked).
    assert
      let
        r = realValidate.sopsRuntimePathR realConst.secrets.runtimePath "nixos/core/db/pg";
      in
      result.isOk r && result.unwrap r == "/run/secrets/nixos/core/db/pg";
    assert !(result.isOk (realValidate.sopsRuntimePathR realConst.secrets.runtimePath "a//b"));
    # 7. Resolution pass, EMPTY branch: zero *.yaml under the base —
    #    the fresh-clone entry state. The declared secret resolves Ok
    #    (tolerated with a trace); strictness is owed only post-bootstrap.
    assert
      let
        r = realValidate.sopsFileR root emptyBase missingRel;
      in
      result.isOk r && result.unwrap r == realFn.sopsFile root emptyBase missingRel;
    "eval-assertions-passed";
in
{
  name = "lib_shared_shared_validate";
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

    with subtest("validate: Result railway — ok/err lanes + boundary throw + EMPTY tolerance"):
        # ${evalAssertions} — if this line renders, the secret-path
        # railway still answers every question the leaves ask, in both
        # lifecycle states (EMPTY and provisioned).
        machine.succeed("true")
  '';
}
