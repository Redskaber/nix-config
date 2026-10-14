# @path: ~/projects/configs/nix-config/tests/platform-grammar.nix
# @author: redskaber
# @datetime: 2026-10-14
# @description: tests::platform-grammar — the fifth repo-hygiene gate (T46)
# @source: the README「目录语法」six laws (grammar v4), asserted as tree shape
#
# THE CLASS THIS GATE KILLS — shape violations the tree can carry while
#   every semantic gate stays green:
#   run #369 (38614372367, 0dbf93b) — the additive v4 adoption left 82
#   v3 corpses on disk: three v3 top doors (platform/<tag>/default.nix),
#   five arch-line payload rows (home/<arch>.nix), and 74 top-level
#   module trees (platform/nixos/{core,dm,wm}). The reachability gate
#   caught them — but only as DANGLING nodes, after a full graph walk,
#   and only because their default.nix files made them module dirs; a
#   corpse WITHOUT a default.nix is not even a module dir and is
#   invisible to it. Shape is decidable from the tree alone: the
#   grammar says exactly which names may sit at which depth, and this
#   gate asserts that — the fast-feedback layer the roadmap promised
#   for this defect class, permanently.
#
# WHAT THIS GATE DOES — the v4 grammar, as four invariants (a pure
#   readDir walk, zero evaluation of anything outside platform/):
#   1. TAG LEVEL — platform/ holds only platform-tag DIRECTORIES; a
#      file at the top level has no grammar address (kind: the v3
#      top-door corpse sat exactly here).
#   2. DOMAIN SET — under platform/<tag>/, only the two reserved
#      domain names are legal (system, home), and at least one must be
#      present: a tag with no domain is a dead address. The v3 top-level
#      module trees (core/dm/wm) violate exactly this invariant.
#   3. DOORS — every domain directory carries a default.nix that is a
#      regular file (the door IS the payload — law 2).
#   4. PAYLOAD — at the domain level, only the door and MODULE
#      directories (dirs containing default.nix) are legal: a bare
#      .nix file is the arch-line corpse class (law 3 — the arch axis
#      has no address on disk), and a directory without a door is
#      invisible to EVERY gate (it is not a module dir, so even
#      module-reachability cannot see it).
#   Deeper levels are payload freedom (README: subdir | file, 自由生
#   长) — wiring there is module-reachability's ledger, not shape.
#
# SCOPE DISCIPLINE — pure tree shape, nothing else. The gate does NOT
#   cross-check the tag set against the dispatch layer (law 5 already
#   makes a missing door fail loudly at eval), does NOT evaluate a
#   single module, and does NOT parse edges — which is exactly why it
#   is cheap, why it can never false-green on a shape it should catch,
#   and why it complements rather than duplicates module-reachability:
#   this gate rejects the ADDRESS SPACE, that gate audits the WIRING
#   inside it.
#
# NO EXEMPTION LEDGER — unlike module-reachability (where "parked on
#   purpose" is a legitimate wiring state), an out-of-grammar entry
#   has no legitimate parked state: if the grammar itself moves (a
#   third reserved domain, say), the change updates reservedDomains
#   and the README laws in the same commit — the gate travels with the
#   grammar, it never disagrees with it.
#
# GATING — same shape as the four sibling gates: `nix flake check
#   --no-build` only EVALUATES this derivation (it always constructs
#   fine); the assertion fires at BUILD time, which is why CI STAGE 1
#   builds this check explicitly, deep-eval Face 3 forces its drvPath,
#   and Face 4's owned list names it.
{
  self,
  shared,
  inputs,
  ...
}:
let
  lib = shared.pkgs.lib;
  pkgs = shared.pkgs;

  inherit (builtins)
    attrNames
    concatMap
    elem
    filter
    length
    pathExists
    readDir
    ;
  inherit (lib)
    concatLists
    concatStringsSep
    removePrefix
    ;

  # ── string-land border ─────────────────────────────────────────────
  # Same rationale as module-reachability: paths carry context since
  # Nix 2.18 (flake self especially) and pure eval rejects those at the
  # file-reading builtins. The scan reads the materialised flake
  # source, so discarding the context once, here, is sound.
  str = p: builtins.unsafeDiscardStringContext (toString p);

  platformTop = str (self + "/platform");

  # ── the grammar ────────────────────────────────────────────────────
  reservedDomains = [
    "system"
    "home"
  ];

  topEntries = readDir platformTop;
  topNames = attrNames topEntries;
  tags = filter (n: topEntries.${n} == "directory") topNames;

  # 1. tag level — only tag directories may sit at platform/
  topViolations = map (n: {
    kind = "file at platform/ top level (a tag is a directory)";
    path = "platform/" + n;
  }) (filter (n: topEntries.${n} != "directory") topNames);

  # per tag: the domain set + the per-domain shape
  domainNames =
    tag: filter (n: elem n reservedDomains) (attrNames (readDir (platformTop + "/" + tag)));

  domainDirs = concatMap (tag: map (dom: platformTop + "/" + tag + "/" + dom) (domainNames tag)) tags;

  tagViolations = concatMap (
    tag:
    let
      tagEntries = readDir (platformTop + "/" + tag);
      names = attrNames tagEntries;
      foreign = filter (n: !(elem n reservedDomains)) names;
    in
    concatLists [
      # 2. domain set — only {system, home}, at least one
      (map (n: {
        kind =
          if tagEntries.${n} == "directory" then
            "unreserved subdomain (grammar v4 reserves only system/ and home/)"
          else
            "file at tag level (the v3 top-door corpse class)";
        path = "platform/" + tag + "/" + n;
      }) foreign)
      (
        if domainNames tag == [ ] then
          [
            {
              kind = "tag without any domain door";
              path = "platform/" + tag;
            }
          ]
        else
          [ ]
      )
    ]
  ) tags;

  # 3+4. per-domain: door shape + payload shape — the violation records
  # carry the platform-relative path verbatim, which names the tag for
  # the reader; no back-mapping is needed.
  shapeViolations = concatMap (
    d:
    let
      entries = readDir d;
      names = attrNames entries;
      doorType = entries.${"default.nix"} or null;
      rel = "platform/" + removePrefix (platformTop + "/") d;
    in
    concatLists [
      (
        if doorType == "regular" then
          [ ]
        else
          [
            {
              kind =
                if doorType == null then "domain without its default.nix door" else "door is not a regular file";
              path = rel;
            }
          ]
      )
      (concatMap (
        n:
        if n == "default.nix" then
          [ ] # the door — reported above if malformed
        else if entries.${n} == "directory" then
          (
            if pathExists (d + "/" + n + "/default.nix") then
              [ ] # a module dir: legal payload
            else
              [
                {
                  kind = "directory without default.nix at domain level (invisible to every gate)";
                  path = rel + "/" + n;
                }
              ]
          )
        else
          [
            {
              kind = "bare file at domain level (the v3 arch-line corpse class)";
              path = rel + "/" + n;
            }
          ]
      ) names)
    ]
  ) domainDirs;

  violations = topViolations ++ tagViolations ++ shapeViolations;

  # payload module dirs: the legal non-door entries at domain level
  payloadDirs = concatMap (
    d:
    let
      entries = readDir d;
    in
    filter (
      n: n != "default.nix" && entries.${n} == "directory" && pathExists (d + "/" + n + "/default.nix")
    ) (attrNames entries)
  ) domainDirs;
in
{
  platform-grammar-check =
    pkgs.runCommand "platform-grammar-check"
      {
        # Forces the report at eval time (empty costs nothing — same
        # forcing pattern as module-reachability's twin reports).
        reportViolations =
          if violations == [ ] then
            ""
          else
            "\n" + concatStringsSep "\n" (map (v: "  - ${v.kind}: ${v.path}") violations);
        tagCount = toString (length tags);
        doorCount = toString (length domainDirs);
        payloadDirCount = toString (length payloadDirs);
        violationCount = toString (length violations);
      }
      ''
        set -euo pipefail
        if [ -n "$reportViolations" ]; then
          echo "" >&2
          echo "platform-grammar: TREE SHAPE VIOLATES GRAMMAR v4:$reportViolations" >&2
          echo "" >&2
          echo "The grammar (README「目录语法」): platform/<tag>/{system,home}/default.nix —" >&2
          echo "domain-explicit, arch axis retired, door IS the payload." >&2
          echo "Reconciliation, in likelihood order:" >&2
          echo "  1. v3 remnant — run #369's 82 corpses were exactly these kinds (top" >&2
          echo "     doors, arch-line files, top-level module trees); the sweep is 1176c6c" >&2
          echo "  2. misplaced module — it belongs under a domain payload dir or in the" >&2
          echo "     cross-platform home/ library, not at a grammar address level" >&2
          echo "  3. the grammar moved — a new reserved domain is a grammar revision:" >&2
          echo "     update reservedDomains in tests/platform-grammar.nix and the README" >&2
          echo "     six laws in the same commit (the gate travels with the grammar)" >&2
          exit 1
        fi
        mkdir -p "$out"
        echo "platform-grammar: $tagCount tags · $doorCount domain doors · $payloadDirCount payload module dirs · 0 violations (grammar v4: {system,home} only, doors required, module-dir payloads only)" > "$out/summary"
        cat "$out/summary"
      '';
}
