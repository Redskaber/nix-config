# @path: ~/projects/configs/nix-config/tests/docs-ssot.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: tests::docs-ssot — docs single-source-of-truth contract check (T8.1)
# @directory: https://github.com/wimpysworld/nix-config
#
# The docs-SSOT half of `checks` (T8.1), the pre-commit-check's sibling
# in repo hygiene. Composed in flake.nix as
#
#   checks.<sys> = (import ./tests { … })            # 92 tests
#               // (import ./tests/pre-commit.nix { … })  # + pre-commit-check
#               // (import ./tests/docs-ssot.nix { … });  # + this check
#
# WHY THIS EXISTS — count drift is this repo's recurring defect class:
# T6.5 reconciled seven squashed-away facts (test-table counts, inputs
# count, zen-browser rows), T7.3 found the CI diagram still saying 91
# after T7.2's +1, and the very design pass for THIS check caught three
# more live ones (devShells quick-ref missing the makeOs row while the
# live output has 25 shells; two test-matrix section headers stuck at
# pre-T5.14 counts). Prose numbers rot because nothing forces them.
#
# WHAT IT DOES — the inverse of test-count.sh: instead of parsing the
# tree to print numbers for humans to copy into README, it EVALUATES
# the live facts (tests/planes/inputs/devShells/hosts — attrNames and
# mapAttrs, never prose) and asserts that the canonical ANCHOR
# sentences in README.md and docs/tests/test-matrix.md still carry
# exactly those numbers. Pattern credit: wimpy's
# checks.assistant-catalogue (generated-doc vs source-of-truth diff),
# adapted to assert-embedded anchors because this README is
# handcrafted prose, not a generated artifact.
#
# THE CONTRACT — anchored lines are load-bearing: rewording around
# them is free, but a count that legitimately changes (new test, new
# host, new input…) must update its anchor sentence in the same
# commit, and the check's own formula travels with it. Only canonical
# claims are anchored (the TEST LAYER box, the suite SSOT sentence,
# the quick-ref headers, the matrix summary); contextual mentions
# elsewhere in prose are unanchored on purpose — anchoring every
# sentence would make README uneditable.
#
# GATING — `nix flake check --no-build` only EVALUATES this derivation
# (it always constructs fine); the drift assertion fires at BUILD time,
# which is why CI STAGE 1 builds this check explicitly right after
# pre-commit-check (same rationale: plane-less checks are not selected
# by any nix-fast-build plane leg).
#
# ARGUMENTS are deliberately key-level only (attrNames / mapAttrs over
# sets already evaluated elsewhere): this check adds zero evaluation
# beyond what checks.<sys> pays anyway (T5.10 single-instantiation
# discipline), and it must not appear inside tests.planes — it counts
# them, so membership would be circular (the flake-level composition
# keeps the counted set and the counter in separate thunks).

{
  inputs,
  self,
  shared,
  tests,
  inventory,
  devShellNames,
  ...
}:
let
  lib = shared.pkgs.lib;

  # ── Live SSOT facts (evaluated, never parsed from prose) ─────────
  planeCounts = lib.mapAttrs (_: p: builtins.length (builtins.attrNames p)) tests.planes;
  planesTotal = builtins.length (builtins.attrNames tests.planes);
  testsTotal = builtins.length (builtins.attrNames tests.checks);
  # + pre-commit-check + this check — both flake-level, both outside
  # tests.checks, so the counted set never contains the counter.
  checksTotal = testsTotal + 2;
  # `inputs` is the @-capture of the outputs arguments, which Nix
  # always augments with `self` — the README claim counts DECLARED
  # inputs only.
  inputsCount = builtins.length (builtins.attrNames (builtins.removeAttrs inputs [ "self" ]));
  devShellsCount = builtins.length devShellNames;
  hostsCount = builtins.length inventory.hostNames;

  t = builtins.toString;

  # ── Anchor registry: one record = one machine-checked claim ──────
  # file: which doc; kind: F = fixed-string (grep -F), E = ERE
  # (grep -E, for table rows whose cell padding may be re-aligned);
  # fact: the human name printed on drift; needle: the exact anchor.
  anchors = [
    # README — the canonical claims
    {
      file = "README";
      kind = "F";
      fact = "test-layer box formula";
      needle = "${t planesTotal} 平面 · ${t testsTotal} tests + pre-commit + docs-ssot = ${t checksTotal} checks";
    }
    {
      file = "README";
      kind = "F";
      fact = "test-suite SSOT sentence";
      needle = "**${t checksTotal} checks = ${t testsTotal} tests + 1 pre-commit-check + 1 docs-ssot-check**";
    }
    {
      file = "README";
      kind = "F";
      fact = "devShells quick-ref header";
      needle = "可用 devShells 速查（${t devShellsCount} 个，";
    }
    {
      file = "README";
      kind = "F";
      fact = "platform-matrix devShells cell";
      needle = "全部（${t devShellsCount} devShells）";
    }
    {
      file = "README";
      kind = "F";
      fact = "flake inputs count";
      needle = "flake.nix（${t inputsCount} inputs）";
    }
    {
      file = "README";
      kind = "F";
      fact = "hosts count sentence";
      needle = "当前承载 **${t hostsCount} 台主机**（nixos · vm · darwin · wsl · nixos-wsl）";
    }
    # test-matrix — per-plane section headers (fixed strings)
    {
      file = "MATRIX";
      kind = "F";
      fact = "matrix header · smoke";
      needle = "### 3.0 Smoke (${t planeCounts.smoke} test)";
    }
    {
      file = "MATRIX";
      kind = "F";
      fact = "matrix header · nixos";
      needle = "### 3.1 NixOS-Plane (${t planeCounts.nixos} tests)";
    }
    {
      file = "MATRIX";
      kind = "F";
      fact = "matrix header · home";
      needle = "### 3.2 HM-Plane (${t planeCounts.home} tests)";
    }
    {
      file = "MATRIX";
      kind = "F";
      fact = "matrix header · lib";
      needle = "### 3.3 Lib-Plane (${t planeCounts.lib} tests)";
    }
    {
      file = "MATRIX";
      kind = "F";
      fact = "matrix header · integration";
      needle = "### 3.4 Integration-Plane (${t planeCounts.integration} test)";
    }
    {
      file = "MATRIX";
      kind = "F";
      fact = "matrix header · nmt";
      needle = "### 3.5 nmt-Plane (${t planeCounts.nmt} tests, 零 VM)";
    }
    # test-matrix — summary table rows (ERE: padding-tolerant)
    {
      file = "MATRIX";
      kind = "E";
      fact = "matrix row · smoke";
      needle = "\\| Smoke +\\| +${t planeCounts.smoke} +\\|";
    }
    {
      file = "MATRIX";
      kind = "E";
      fact = "matrix row · nixos";
      needle = "\\| NixOS +\\| +${t planeCounts.nixos} +\\|";
    }
    {
      file = "MATRIX";
      kind = "E";
      fact = "matrix row · home";
      needle = "\\| HM +\\| +${t planeCounts.home} +\\|";
    }
    {
      file = "MATRIX";
      kind = "E";
      fact = "matrix row · lib";
      needle = "\\| Lib +\\| +${t planeCounts.lib} +\\|";
    }
    {
      file = "MATRIX";
      kind = "E";
      fact = "matrix row · integration";
      needle = "\\| Integration +\\| +${t planeCounts.integration} +\\|";
    }
    {
      file = "MATRIX";
      kind = "E";
      fact = "matrix row · nmt";
      needle = "\\| \\*\\*nmt\\*\\* +\\| +\\*\\*${t planeCounts.nmt}\\*\\* +\\|";
    }
    {
      file = "MATRIX";
      kind = "E";
      fact = "matrix row · total";
      needle = "\\| \\*\\*Total\\*\\* +\\| +\\*\\*${t testsTotal}\\*\\* +\\|";
    }
  ];

  # The two audited documents are shell variables in the builder; the
  # anchor records name them symbolically and this maps to the variable
  # REFERENCE (dollar-prefixed, expanded at the call site) — passing the
  # bare name would make grep open a file literally called "README".
  docVar = a: if a.file == "README" then "$README" else "$MATRIX";

  # Render one anchor into its bash expectation line.
  render =
    a:
    if a.kind == "F" then
      ''expectF "${docVar a}" "${a.fact}" "${a.needle}"''
    else
      ''expectE "${docVar a}" "${a.fact}" "${a.needle}"'';

  expectations = lib.concatStringsSep "\n" (map render anchors);

  drv =
    shared.pkgs.runCommand "docs-ssot-check"
      {
        # Traceability: the two audited documents as derivation inputs.
        documentation = [
          "${self}/README.md"
          "${self}/docs/tests/test-matrix.md"
        ];
      }
      ''
        set -u
        export LC_ALL=C

        README="${self}/README.md"
        MATRIX="${self}/docs/tests/test-matrix.md"

        FAILED=0

        # expectF <file-var> <fact> <fixed needle> — grep -F (literal bytes).
        expectF() {
          if grep -qF -- "$3" "$1"; then
            echo "docs-ssot: ok    $2"
          else
            echo "docs-ssot: DRIFT $2 — $1 no longer carries the canonical anchor:" >&2
            echo "    $3" >&2
            echo "    The live evaluation says this number is current; update the doc," >&2
            echo "    or, if a fact legitimately changed, the anchor sentence travels" >&2
            echo "    in the same commit (see tests/docs-ssot.nix header)." >&2
            FAILED=1
          fi
        }

        # expectE <file-var> <fact> <ERE> — for padding-tolerant table rows.
        expectE() {
          if grep -qE -- "$3" "$1"; then
            echo "docs-ssot: ok    $2"
          else
            echo "docs-ssot: DRIFT $2 — $1 summary row does not match the ERE:" >&2
            echo "    $3" >&2
            FAILED=1
          fi
        }

        # The anchor battery — ${toString (builtins.length anchors)} machine-checked
        # claims, generated from the live facts at evaluation time.
        ${expectations}

        if [ "$FAILED" -ne 0 ]; then
          echo "" >&2
          echo "docs-ssot-check FAILED: documentation anchors drifted from live facts." >&2
          echo "Counts are single-sourced from the evaluation; the docs must follow." >&2
          exit 1
        fi

        echo "docs-ssot-check: all ${toString (builtins.length anchors)} anchors agree with live facts"
        echo "  tests ${t testsTotal} (planes ${t planesTotal}: smoke ${t planeCounts.smoke} + nixos ${t planeCounts.nixos} + home ${t planeCounts.home} + lib ${t planeCounts.lib} + integration ${t planeCounts.integration} + nmt ${t planeCounts.nmt})"
        echo "  checks ${t checksTotal} (tests + pre-commit-check + docs-ssot-check)"
        echo "  inputs ${t inputsCount} · devShells ${t devShellsCount} · hosts ${t hostsCount}"
        touch "$out"
      '';

in
# Wrapped in an attrset on purpose — the pre-commit.nix history note:
# returning a derivation bare from a module merged with `//` SPILLS its
# drv attrs into the output set and silently drops the member
# (outPath/__structuredAttrs/userHook… surface as checks members). The
# face eval catches it; this shape prevents it.
{
  docs-ssot-check = drv;
}
