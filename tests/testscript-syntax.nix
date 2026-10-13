# @path: ~/projects/configs/nix-config/tests/testscript-syntax.nix
# @author: redskaber
# @datetime: 2026-10-13
# @description: tests::testscript-syntax — the third repo-hygiene gate (T32)
# @source: self (the flake source tree) × tests/**.nix (the fleet)
#
# THE CLASS THIS GATE KILLS — the CI lib-plane red of this round:
# a multi-line nix value interpolated into a single-line python
# comment inside a testScript literal. The 99th test (lib_shared_orc,
# T28) spliced its 8-line contractHeld behind one '#':
#
#     # ${contractHeld} — renders only if every site held; the
#
# Only the spliced FIRST line stayed behind the '#'; the seven site
# verdict lines arrived as bare python, and the CI driver's pylyzer
# run (testScriptWithTypes) rejected the whole member — 83
# diagnostics, one red plane, while the local eval-level verification
# (drvPath) had been green all along: evaluating a derivation never
# parses the python embedded in it. The driver build was the ONLY
# place the parse happened — and it needs the whole VM closure, so it
# is the most expensive possible layer for it.
#
# WHAT THIS GATE DOES — moves the parse to the cheapest layer:
#   1. EVAL time: walk tests/**.nix, call each file directly with the
#      runner's argument superset (pkgs/inputs/shared/lib/self), and
#      read its `testScript` attribute — the call re-runs the module
#      body (the eval-time contracts live there; a contract throw is
#      swallowed by the probe here and reported by tests.checks —
#      the division of labour is deliberate), and forcing the string
#      resolves every ${...} interpolation. The text this gate
#      python-compiles is therefore the SAME composed text the CI
#      driver would run — no source-level approximation.
#   2. BUILD time: python-compile each extracted script (pure
#      compile(), no execution) and fail with the verbatim error plus
#      the reconciliation.
#
# WHY A DIRECT CALL, NOT THE MODULE SYSTEM: the framework evaluates
# testScript through options that drag `nodes` (full NixOS
# evaluation, the VM closure) with them; the direct call leaves
# `nodes` as an unevaluated attrset value (nix laziness), so the
# gate sees the script at near-zero cost. The probe is
# conservative-by-construction: any file that is not a test module
# either throws on the call (skipped) or returns an attrset without a
# testScript key (skipped) — and any REAL breakage in a test module
# also breaks tests.checks, which evaluates the same module through
# the real runner. The gate's unique coverage is exactly the python
# syntax class the driver build would otherwise be alone in catching.
#
# SPLICE DISCIPLINE (the rule the 99th now follows): a multi-line
# nix value goes into a python STRING EXPRESSION ("""…${value}…"""),
# never into a `#` comment or a single-quoted string — newlines
# inside those break the python. Single-line values in comments are
# fine (the fleet's `# ${evalAssertions} — renders only if…` idiom is
# load-bearing and green since T3.4).
#
# GATING — same shape as the other two hygiene gates (T8.1's
# rationale): `nix flake check --no-build` only EVALUATES this
# derivation (it always constructs fine); the syntax assertion fires
# at BUILD time, which is why CI STAGE 1 builds this check
# explicitly right after pre-commit-check and docs-ssot-check, and
# deep-eval Face 3 forces its drvPath.
{
  self,
  shared,
  inputs,
  ...
}:
let
  lib = shared.pkgs.lib;
  pkgs = shared.pkgs;

  # ── the fleet, from the source tree ─────────────────────────────
  # The gate file itself is excluded: its own body mentions the
  # word testScript, so probing it would re-enter the gate's let
  # block and recurse infinitely.
  gateFile = toString self + "/tests/testscript-syntax.nix";

  testFiles = builtins.filter (p: (lib.hasSuffix ".nix" p) && (toString p != gateFile)) (
    lib.filesystem.listFilesRecursive (self + "/tests")
  );

  # Layer 1 — the SOURCE mentions testScript: the nmt-format files
  # and the fixtures never carry one, so one readFile+hasInfix
  # removes them without any call at all (their bodies throw
  # attr-selection errors on a plain lib — see the probe comment
  # for why tryEval cannot save us there).
  mentionsScript = p: lib.hasInfix "testScript" (builtins.readFile p);
  candidates = builtins.filter mentionsScript testFiles;

  # ── the probe: direct call, runner's argument superset ─────
  # Two-stage, because of a Nix semantic learned the hard way:
  # `builtins.tryEval` does NOT catch argument-pattern failures
  # ("function called without required argument") — they are fatal
  # straight through (verified on 2.35.2 with a minimal reproduction;
  # `throw` is catchable, missing args are not). So the probe checks
  # `builtins.functionArgs` FIRST — a file whose REQUIRED arguments
  # reach outside the superset (docs-ssot.nix wants
  # tests/inventory/devShellNames) is skipped without ever being
  # called; only then does the tryEval'd call happen (its guarding
  # covers the semantic errors).
  provided = {
    inherit
      pkgs
      inputs
      shared
      self
      ;
    lib = pkgs.lib;
  };

  missingRequired =
    mod:
    let
      args = builtins.functionArgs mod;
    in
    builtins.filter (n: !builtins.hasAttr n provided) (
      lib.attrNames (lib.filterAttrs (_: hasDefault: !hasDefault) args)
    );

  # `called.success` is false for files that are not test modules
  # (semantic errors on the call OR IN THE BODY — tryEval only
  # guards what its own expression forces, so the `? testScript`
  # probe and the isString check live INSIDE it; the body thunk of a
  # module like the nmt files throws on our lib and must be caught
  # there) — they are out of this gate's scope. A contract throw
  # inside a real test module is also swallowed here; tests.checks
  # evaluates the same module through the real runner and reports it
  # there — this gate's unique coverage is syntax, not semantics.
  probe =
    path:
    let
      mod = import path;
    in
    if !builtins.isFunction mod then
      false
    else if missingRequired mod != [ ] then
      false
    else
      let
        called = builtins.tryEval (
          let
            v = mod provided;
          in
          v ? testScript && builtins.isString v.testScript
        );
      in
      called.success && called.value;

  testsWithScripts = builtins.filter probe candidates;

  # A test module whose testScript is a FUNCTION (the framework
  # supports `{ nodes, ... }: ''…''`): not present in the fleet today
  # (verified); refusing it here turns a future function-form into a
  # conscious gate extension instead of a silent skip.
  functionForm =
    path:
    let
      mod = import path;
    in
    if !builtins.isFunction mod then
      false
    else if missingRequired mod != [ ] then
      false
    else
      let
        called = builtins.tryEval (
          let
            v = mod provided;
          in
          v ? testScript && builtins.isFunction v.testScript
        );
      in
      called.success && called.value;
  functionForms = builtins.filter functionForm candidates;
  functionFormRefusal =
    if functionForms == [ ] then
      null
    else
      throw ''
        testscript-syntax: function-form testScript found (unsupported):
          ${lib.concatStringsSep "\n  " (map toString functionForms)}

        The gate python-compiles the STRING form only. Extend the gate
        in the same commit that introduces the first function-form
        (call it with a stubbed nodes record and compile the result).
      '';

  # ── materialise each composed script as a store file ───────────
  # Forcing the string resolves every ${...} — this is the composed
  # text, not the literal.
  scriptOf =
    path:
    let
      mod = import path;
      called = mod provided;
      rel = lib.removePrefix "${toString self}/" (toString path);
      safe = lib.replaceStrings [ "/" ] [ "_" ] rel;
    in
    pkgs.writeText "tss-${safe}.py" called.testScript;

  scripts = map scriptOf testsWithScripts;

  # The count travels into the check's output so a probe regression
  # (a runner-side args change making every call throw) is visible as
  # a suspicious drop, not a silent green.
  scriptCount = builtins.length scripts;
in
{
  testscript-syntax-check =
    pkgs.runCommand "testscript-syntax-check"
      {
        nativeBuildInputs = [ pkgs.python3 ];
        # Forces the function-form refusal (a tripwire, not dead code:
        # a future function-form testScript turns THIS gate red at
        # eval time — toString null is "" and toString on the throw
        # propagates it). deadnix's catch made the wiring honest.
        refusal = toString functionFormRefusal;
      }
      ''
        set -euo pipefail
        fails=0
        total=0
        for f in ${lib.concatStringsSep " " (map toString scripts)}; do
          total=$((total + 1))
          if ! python3 -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' "$f" 2>/tmp/tss-err; then
            echo "" >&2
            echo "testscript-syntax: $f does not parse as python:" >&2
            cat /tmp/tss-err >&2
            fails=1
          fi
        done
        if [ "$fails" -ne 0 ]; then
          echo "" >&2
          echo "testscript-syntax-check FAILED: a testScript does not parse as python." >&2
          echo "The CI driver (pylyzer, testScriptWithTypes) rejects the whole member" >&2
          echo "at BUILD time — this gate surfaces the same class before any VM" >&2
          echo "closure is built." >&2
          echo "Reconciliation, in likelihood order:" >&2
          echo "  1. a multi-line nix value was spliced into a '#' comment or a" >&2
          echo "     single-quoted string — only the first line stays behind the '#';" >&2
          echo "     splice multi-line values into a triple-quoted python string" >&2
          echo "     expression instead:" >&2
          echo '         """' >&2
          echo '         ''${value}' >&2
          echo '         """' >&2
          echo "  2. bare prose inside the testScript literal — rationale belongs in" >&2
          echo "     nix comments ABOVE testScript, python comments ('#') inside it" >&2
          echo "  3. a string/indentation typo in the literal itself" >&2
          exit 1
        fi
        mkdir -p "$out"
        echo "testscript-syntax: ${toString scriptCount} testScripts parsed green (composed at eval time, compiled at build time)" > "$out/summary"
        cat "$out/summary"
      '';
}
