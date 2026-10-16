# @path: ~/projects/configs/nix-config/tests/docs-ssot.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: tests::docs-ssot — docs single-source-of-truth contract check
# @directory: https://github.com/wimpysworld/nix-config
#
# The docs-SSOT half of `checks`, the pre-commit-check's sibling
# in repo hygiene. Composed in lib/shared/faces.nix (the linker
# pass) as
#
#   checks.<sys> = (import ./tests { … })            # 92 tests
#               // (import ./tests/pre-commit.nix { … })  # + pre-commit-check
#               // (import ./tests/docs-ssot.nix { … });  # + this check
#
# WHY THIS EXISTS — count drift and dead navigation are this
# repo's recurring defect classes: prose numbers rot because
# nothing forces them, and TOC links outlive the sections they
# point at (the gate was born after a real catch: the TOC
# listed two sections the body no longer carried — every
# other gate green, GitHub rendering dead links).
#
# WHAT IT DOES — the inverse of test-count.sh: instead of parsing the
# tree to print numbers for humans to copy into README, it EVALUATES
# the live facts (tests/planes/inputs/devShells/hosts — attrNames and
# mapAttrs, never prose) and asserts that the canonical ANCHOR
# sentences in README.md and docs/tests/test-matrix.md still carry
# exactly those numbers. On top of the count anchors, a TOC navigation
# battery proves the README's own navigation: numbered TOC entries
# (sequential, text ↔ heading, slug ↔ anchor), every internal
# ](#target) link resolving to a real heading, and no orphan sections.
# The third battery (round 32) is EN-PARITY: docs/en/ is the English
# mirror plane of docs/ and README.en.md the README mirror — the
# Chinese originals are canonical, so the assertion is structural, not
# content-equality: every translatable doc must have a mirror, no
# orphan mirror may exist, and the README mirror must be present.
# A mirror tree that can silently lose files is exactly the drift
# class this gate family refuses to carry.
# Pattern credit: wimpy's
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
# beyond what checks.<sys> pays anyway (the single-instantiation
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
  # + pre-commit-check + docs-ssot-check + testscript-syntax-check
  # + module-reachability-check + platform-grammar-check
  # + cache-ssot-check — all six flake-level, all outside
  # tests.checks, so the counted set never contains the counter.
  checksTotal = testsTotal + 6;
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
      needle = "${t planesTotal} 平面 · ${t testsTotal} tests + 6 仓库卫生门 = ${t checksTotal} checks";
    }
    {
      file = "README";
      kind = "F";
      fact = "test-suite SSOT sentence";
      needle = "**${t checksTotal} checks = ${t testsTotal} tests + 1 pre-commit-check + 1 docs-ssot-check + 1 testscript-syntax-check + 1 module-reachability-check + 1 platform-grammar-check + 1 cache-ssot-check**";
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
    # README's own per-plane table rows — anchored too, not just the
    # MATRIX file's rows (a row count that drifts here is invisible
    # to the matrix anchors). Same ERE shape as the matrix-row
    # anchors below, adapted to the README table's prefix column.
    {
      file = "README";
      kind = "E";
      fact = "README plane-table row · smoke";
      needle = "\\| Smoke +\\| +\\`test_\\` +\\| +${t planeCounts.smoke} +\\|";
    }
    {
      file = "README";
      kind = "E";
      fact = "README plane-table row · nixos";
      needle = "\\| NixOS +\\| +\\`nixos_\\` +\\| +${t planeCounts.nixos} +\\|";
    }
    {
      file = "README";
      kind = "E";
      fact = "README plane-table row · home";
      needle = "\\| HM +\\| +\\`home_\\` +\\| +${t planeCounts.home} +\\|";
    }
    {
      file = "README";
      kind = "E";
      fact = "README plane-table row · lib";
      needle = "\\| Lib +\\| +\\`lib_\\` +\\| +${t planeCounts.lib} +\\|";
    }
    {
      file = "README";
      kind = "E";
      fact = "README plane-table row · integration";
      needle = "\\| Integration +\\| +\\`integration_\\` +\\| +${t planeCounts.integration} +\\|";
    }
    {
      file = "README";
      kind = "E";
      fact = "README plane-table row · nmt";
      needle = "\\| \\*\\*nmt\\*\\* +\\| +\\`nmt_\\` +\\| +\\*\\*${t planeCounts.nmt}\\*\\* +\\|";
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
        # Traceability: the audited documents as derivation inputs —
        # the two count-anchored files plus the English mirror plane's
        # root file (its siblings enter via the tree walk below).
        documentation = [
          "${self}/README.md"
          "${self}/README.en.md"
          "${self}/docs/tests/test-matrix.md"
        ];
      }
      ''
        set -u
        export LC_ALL=C

        README="${self}/README.md"
        MATRIX="${self}/docs/tests/test-matrix.md"
        DOCS_DIR="${self}/docs"
        EN_DIR="${self}/docs/en"
        README_EN="${self}/README.en.md"

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

        # ── TOC navigation battery ──────────────────────────────────
        # The anchors above prove numeric claims; this battery proves
        # NAVIGATION claims. Born from a real defect: the TOC listed
        # 已知边界与设计债 + 深入文档 while both sections were missing
        # from the body — every count anchor green, GitHub rendering
        # dead links. Three assertions:
        #   A. numbered TOC entries — sequential numbering, entry text
        #      equals a real ## heading, slug(heading) == anchor
        #   B. every internal ](#target) link (TOC + inline prose)
        #      resolves to some heading's slug
        #   C. every ## heading except the TOC's own (目录) is indexed

        gh_slug() {
          # GitHub's heading → anchor rendering for this README's
          # charset inventory: CJK retained, ASCII lowered, spaces
          # → dashes, ASCII and typographic punctuation removed.
          # LC_ALL=C makes sed byte-wise: the class keeps all high
          # bytes (CJK) while dropping ASCII punctuation, then the
          # explicit strips remove the typographic UTF-8 sequences
          # that survived the class (em-dash · （） ： …).
          local high
          high=$(printf '\200-\377')
          printf '%s\n' "$1" \
            | tr '[:upper:]' '[:lower:]' \
            | sed -E "s/[^a-z0-9 _''${high}-]//g" \
            | sed -e $'s/\xe2\x80\x94//g' -e $'s/\xc2\xb7//g' \
                  -e $'s/\xef\xbc\x88//g' -e $'s/\xef\xbc\x89//g' \
                  -e $'s/\xef\xbc\x9a//g' -e $'s/\xe2\x80\xa6//g' \
            | tr ' ' '-'
        }

        # Body headings and their GitHub slugs, one per line.
        BODY_HEADINGS=$(mktemp)
        HEADING_SLUGS=$(mktemp)
        sed -n 's/^## //p' "$README" | tee "$BODY_HEADINGS" | while IFS= read -r h; do
          gh_slug "$h"
        done > "$HEADING_SLUGS"

        # A. numbered TOC entries (the 目录 list at the top).
        TOC_TEXTS=$(mktemp)
        expected_num=1
        while IFS= read -r entry; do
          text=$(printf '%s' "$entry" | sed -E 's/^[0-9]+\. \[([^]]+)\].*/\1/')
          anchor=$(printf '%s' "$entry" | sed -E 's/.*\]\(#([^)]+)\).*/\1/')
          num=$(printf '%s' "$entry" | cut -d. -f1)

          if [ "$num" != "$expected_num" ]; then
            echo "docs-ssot: DRIFT TOC numbering — expected $expected_num, got $num at '$entry'" >&2
            FAILED=1
          fi
          expected_num=$((expected_num + 1))

          printf '%s\n' "$text" >> "$TOC_TEXTS"
          if ! grep -qxF -- "$text" "$BODY_HEADINGS"; then
            echo "docs-ssot: DRIFT TOC entry — '$text' has no '## $text' heading (dead link on GitHub)" >&2
            FAILED=1
          else
            want=$(gh_slug "$text")
            if [ "$want" != "$anchor" ]; then
              echo "docs-ssot: DRIFT TOC anchor — '$text' targets #$anchor, but the heading slugs to #$want" >&2
              FAILED=1
            fi
          fi
        done < <(grep -E '^[0-9]+\. \[[^]]+\]\(#[^)]+\)' "$README")

        # B. every internal ](#target) link resolves to a heading slug.
        while IFS= read -r target; do
          [ -n "$target" ] || continue
          if ! grep -qxF -- "$target" "$HEADING_SLUGS"; then
            echo "docs-ssot: DRIFT internal link — ](#$target) resolves to no ## heading" >&2
            FAILED=1
          fi
        done < <(grep -oE '\]\(#[^)]+\)' "$README" | sed -e 's/^](#//' -e 's/)$//')

        # C. completeness — every ## heading except the TOC's own is
        # indexed (the 目录 heading IS the TOC; indexing it is circular).
        while IFS= read -r h; do
          [ "$h" = "目录" ] && continue
          if ! grep -qxF -- "$h" "$TOC_TEXTS"; then
            echo "docs-ssot: DRIFT orphan section — '## $h' is not indexed by the TOC" >&2
            FAILED=1
          fi
        done < "$BODY_HEADINGS"

        toc_total=$(wc -l < "$TOC_TEXTS" | tr -d ' ')

        # ── English-mirror parity battery (round 32) ──────────────
        # docs/en/ mirrors docs/ (same sub-path), README.en.md mirrors
        # README.md. The Chinese originals are canonical; the gate
        # asserts STRUCTURE, not content: (A) every translatable doc
        # has a mirror — modules/interface-standards.md is exempt, it
        # is English canon already and must not be duplicated;
        # (B) no orphan mirror exists without a Chinese counterpart;
        # (C) the README mirror is present and non-empty.

        en_pair=0
        en_missing=0
        while IFS= read -r zh; do
          rel=''${zh#"$DOCS_DIR"/}
          case "$rel" in
            modules/interface-standards.md) continue ;;
          esac
          if [ ! -f "$EN_DIR/$rel" ]; then
            echo "docs-ssot: DRIFT en-parity — missing docs/en/$rel (the English mirror plane is incomplete)" >&2
            en_missing=1
          else
            en_pair=$((en_pair + 1))
          fi
        done < <(find "$DOCS_DIR" -type f -name '*.md' ! -path "$DOCS_DIR/en/*" ! -path "$DOCS_DIR/tmpl/*" | sort)

        while IFS= read -r en; do
          rel=''${en#"$EN_DIR"/}
          if [ ! -f "$DOCS_DIR/$rel" ]; then
            echo "docs-ssot: DRIFT en-parity — orphan docs/en/$rel (no Chinese counterpart to mirror)" >&2
            en_missing=1
          fi
        done < <(find "$EN_DIR" -type f -name '*.md' | sort)

        if [ ! -s "$README_EN" ]; then
          echo "docs-ssot: DRIFT en-parity — README.en.md missing or empty" >&2
          en_missing=1
        fi

        if [ "$en_missing" -ne 0 ]; then
          echo "docs-ssot: en-parity says the mirror plane and the canonical tree disagree." >&2
          echo "    Add the mirror, or retire it in the same commit that removes the Chinese file." >&2
          FAILED=1
        fi

        if [ "$FAILED" -ne 0 ]; then
          echo "" >&2
          echo "docs-ssot-check FAILED: documentation claims drifted (counts, navigation, or parity)." >&2
          echo "Counts are single-sourced from the evaluation; navigation must resolve; the mirror plane must be whole; the docs must follow." >&2
          exit 1
        fi

        echo "docs-ssot-check: all ${toString (builtins.length anchors)} anchors agree with live facts"
        echo "  toc battery: $toc_total TOC entries resolved (numbering + text + slug), dead links 0, orphan sections 0"
        echo "  en-parity battery: $en_pair docs ↔ docs/en mirrors paired, README.en.md present"
        echo "  tests ${t testsTotal} (planes ${t planesTotal}: smoke ${t planeCounts.smoke} + nixos ${t planeCounts.nixos} + home ${t planeCounts.home} + lib ${t planeCounts.lib} + integration ${t planeCounts.integration} + nmt ${t planeCounts.nmt})"
        echo "  checks ${t checksTotal} (tests + pre-commit-check + docs-ssot-check + testscript-syntax-check + module-reachability-check + platform-grammar-check + cache-ssot-check)"
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
