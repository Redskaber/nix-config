# @path: ~/projects/configs/nix-config/tests/lib/shared/pdshell.nix
# @author: redskaber
# @datetime: 2026-10-13
# @description: tests::lib::shared::pdshell — the pdshell loader consumption contract
# @source: flake.lock (the pinned pdshell, da51c57) × shared.pdshells (the production handle)
#
# With this battery, every tool-library input the config consumes
# (nix-types, nmt, orc, pdshell) has a WHAT battery answering its
# lock's WHERE.
#
# Why this battery matters: devShells are developer-facing, so a
# rotten member fails `nix develop .#name` interactively instead of a
# `switch` — nothing fails loudly, things just quietly stop being
# what the README says. What this battery pins, against the REAL
# tree:
#
#   1. census     — the exact 25-member set. docs-ssot anchors the
#                   COUNT (25) against the quick-ref header, but a
#                   rename keeps the count and passes — membership
#                   needs this census. Also the only tripwire for the
#                   `_`-prefix exclusion (a file named `_x.nix`
#                   vanishes without a word) and for upstream
#                   naming-rule drift (fn-makeFullName semantics —
#                   pdshell's own battery is a single eval smoke
#                   check, no assertions; this is the first).
#   2. face       — every member is a derivation named
#                   `dev-shell-<member>` (fn-buildFlatShells' name
#                   injection contract).
#   3. combinFrom — the root default declares its own buildInputs
#                   as [] — so every input in the merged list must
#                   have arrived through the fourteen language
#                   defaults' contributions (the resolve → extract →
#                   merge pipeline over the real tree).
#   4. lifecycle  — the composed shellHook carries the section
#                   markers, the inherited-before-own order (a
#                   language default's hook precedes the composing
#                   shell's own), and the FINAL SHELL OVERRIDE
#                   exporting the identity-axis shell.
#   5. NamedFile  — python-renpy (a NamedFile sibling, no
#                   combinFrom) carries its own declared inputs (the
#                   renpy engine) and does NOT leak another file's
#                   contribution — the loader isolates siblings.
#
# Construction discipline: the same handle (shared.pdshells) × the
# same argument record faces.nix passes — pkgs, inputs, shared,
# devDir, verbatim — re-run here so the contract is an eval-time
# property of the check build. The flake's single pdsh construction
# stays single (devShells output + the docs-ssot count share it);
# this battery deliberately re-runs the loader because a test that
# did not go through the production handle would test a copy, not
# the consumption.
#
# Version anchors: the four contribution probes and the SHELL export
# derive from the same identity axes the shell files use — routine
# nixpkgs bumps keep them matching (minor-lineage prefixes:
# python3-3.14 tracks the python314 attr, go-1. the go attr). A probe
# that misses means either a language default dropped its input or
# the anchor drifted — the throw names which.
#
# Mutation checks (all verified on the real eval):
#   rename python/machine.nix → machin2.nix  → census: missing "python-machine", stray "python-machin2"
#   _-prefix python/machine.nix             → census: missing "python-machine" (silent exclusion, live proof)
#
# Two design catches from the mutation battery:
#   1. the census must short-circuit the member-specific groups —
#      a raw attribute lookup (pdsh.python-renpy) would swallow the
#      census message under naming drift (a drifted member set makes
#      the specific groups meaningless anyway)
#   2. a DIRECTORY rename that anything references fails loud on
#      its own — the loader's DevScope (dev.<name> lookups) is
#      fail-fast at eval, so the census's silent-rename class is
#      specifically the UNREFERENCED member drift; referenced
#      renames never reach this battery
#
{
  inputs,
  shared,
  lib,
  ...
}:
let
  # ── the REAL loader, through the production handle ────────────
  # The argument record is faces.nix's, verbatim (the devShells
  # loader) — pkgs from the shared instance, the flake inputs, the
  # shared axis set, and the schema's devDir pointing at the real
  # home/env/dev tree.
  pdsh = shared.pdshells {
    inherit pkgs inputs shared;
    devDir = shared.devDir;
  };

  pkgs = shared.pkgs;

  # Pure substring search — substring comparison, no regex, no
  # context sensitivity (regex needles break on store-path and
  # bracket content, and the hook text carries both).
  hasSub =
    needle: haystack:
    let
      n = builtins.stringLength needle;
      h = builtins.stringLength haystack;
      go = i: i + n <= h && (builtins.substring i n haystack == needle || go (i + 1));
    in
    go 0;

  # Substring index (-1 when absent) — for the ORDER assertions:
  # where one marker sits relative to another in the composed hook.
  idxOf =
    needle: haystack:
    let
      n = builtins.stringLength needle;
      h = builtins.stringLength haystack;
      go =
        i:
        if i + n > h then
          -1
        else if builtins.substring i n haystack == needle then
          i
        else
          go (i + 1);
    in
    go 0;

  # ── 1. census — the naming rules applied to the real tree ──────
  # Every rule has a member exercising it: DirectoryRoot at the root
  # (the dir has no name of its own), DirectoryRoot below the root
  # (the dir IS the name), NamedFile (basePath-fileBase), a variant
  # ≠ default (suffix — including the hyphenated one living inside
  # nix/default.nix), and NamedFile under a sub-directory that has
  # no default.nix of its own (nix/derivation/).
  expected = [
    # variants of the root DirectoryRoot (home/env/dev/default.nix)
    "default"
    "cpython"
    "godot"
    "makeOs"
    "rs_compiler_dev"
    # one directory per language (the dir IS the name)
    "asm"
    "c"
    "cpp"
    "go"
    "java"
    "javascript"
    "lisp"
    "lua"
    "nix"
    "python"
    "re"
    "rust"
    "typescript"
    "zig"
    # NamedFile siblings under python/ (fileBase joins the basePath)
    "python-machine"
    "python-renpy"
    # variants ≠ default inside nix/default.nix
    "nix-nonfmt"
    "nix-derivation-free-security"
    # NamedFiles under nix/derivation/ (no default.nix of its own)
    "nix-derivation-free"
    "nix-derivation-unfree"
  ];

  members = builtins.attrNames pdsh;

  # Set-diff both ways: a rename shows as BOTH missing and stray.
  missing = builtins.filter (e: !builtins.elem e members) expected;
  stray = builtins.filter (m: !builtins.elem m expected) members;

  censusHeld = missing == [ ] && stray == [ ];

  # The census report — a throw, not a verdict string: a drifted
  # census makes every member-specific group meaningless, so this
  # fires FIRST (element order in contractHeld is the mechanism; a
  # raw pdsh.<name> lookup under drift would otherwise swallow it).
  census =
    if censusHeld then
      "census ok: ${toString (builtins.length members)} members, exactly the declared set"
    else
      throw ''
        pdshell loader contract violation (T31), census:
          expected ${toString (builtins.length expected)} members, the live
          tree produced ${toString (builtins.length members)}.

          missing (declared here, absent from the loader):
            ${lib.concatStringsSep ", " missing}
          stray (loaded, absent from this census):
            ${lib.concatStringsSep ", " stray}

          Reconciliation, in likelihood order:
            1. the dev tree changed — a file, variant, or directory was
               added/renamed/removed under home/env/dev; re-derive this
               census from the live face
               (`nix eval .#devShells.<arch> --apply builtins.attrNames`)
               and carry the change in the same commit
            2. a file meant to be a shell got a `_` prefix
               (fn-isPrivate) — if it should be a shell, rename it
            3. pdshell's naming rules changed upstream — bump
               pdshell consciously and re-derive this census
            4. docs-ssot anchors the COUNT (quick-ref header); this
               battery anchors the MEMBERSHIP — both must travel
               together
      '';

  # ── 2. face — fn-buildFlatShells' name injection ───────────────
  faceVerdict =
    m:
    let
      name = pdsh.${m}.name or "???";
    in
    if name == "dev-shell-${m}" then
      "face ok: ${m} → ${name}"
    else
      throw ''
        pdshell loader contract violation (T31), face:
          member ${m} is a derivation named "${name}" — expected
          "dev-shell-${m}" (fn-buildFlatShells' name injection).

          Reconciliation:
            1. fn-buildFlatShells' injection changed upstream — bump
               pdshell consciously; this battery documents the face
               contract the fleet's UX depends on
            2. a wrapper layer renamed the derivation — face names are
               load-bearing for `nix develop .#<member>` and the README
               quick-ref
      '';

  # ── 3. combinFrom — contribution through the language defaults ──
  # The root default's OWN buildInputs is [] (home/env/dev/default.nix
  # declares `buildInputs = with shared.upkgs; [ ];`), so every input
  # in the merged list arrived through the fourteen language
  # defaults' contributions — the resolve → extract → merge pipeline
  # over the real tree. Four probes, one per language family.
  defaultInputs = pdsh.default.buildInputs;
  inputNames = map (x: x.name or "???") defaultInputs;
  hasInput = needle: builtins.any (n: hasSub needle n) inputNames;

  contributionProbes = [
    {
      anchor = "python3-3.14";
      why = "the python language default's interpreter";
    }
    {
      anchor = "rust-analyzer";
      why = "the rust language default's LSP";
    }
    {
      anchor = "go-1";
      why = "the go language default's toolchain";
    }
    {
      anchor = "glibc";
      why = "the c/cpp language defaults' libc";
    }
  ];

  combinFromVerdict =
    probe:
    if hasInput probe.anchor then
      "combinFrom ok: ${probe.anchor} present (${probe.why})"
    else
      throw ''
        pdshell loader contract violation (T31), combinFrom:
          the root default's own buildInputs is [] — the merged list
          must carry every input through the fourteen language
          defaults, but the probe "${probe.anchor}" (${probe.why})
          is absent from the ${toString (builtins.length defaultInputs)}
          merged inputs.

          Reconciliation:
            1. a language default dropped the input — check
               home/env/dev/<lang>/default.nix against its quick-ref row
            2. the version anchor drifted (a nixpkgs bump moved the
               minor lineage) — update the probe in the same commit;
               the anchors are prefixes precisely so this is rare
            3. mergeStrategy changed upstream (baseOnly would drop the
               extracted contributions entirely) — bump pdshell
               consciously
      '';

  # ── 4. lifecycle — the composed shellHook ───────────────────────
  # The composed hook carries the labelled sections (fn-assemble's
  # `# === <LABEL> ===` markers), the inherited-before-own order
  # inside a phase section (fn-composePhase: inherited ++ own), and
  # the FINAL SHELL OVERRIDE exporting the identity-axis shell
  # (fn-applyShellOverride). INHERITED SHELLHOOK is empty on the root
  # default (no combinFrom member declares a shellHook) and empty
  # sections are omitted in non-debug assembly — so the asserted
  # marker set is the five that exist on this member.
  hook = pdsh.default.shellHook;

  markers = [
    "PRE-INPUTS HOOK"
    "POST-INPUTS HOOK"
    "PRE-SHELL HOOK"
    "POST-SHELL HOOK"
    "FINAL SHELL OVERRIDE"
  ];

  markerVerdict =
    mk:
    if hasSub "# === ${mk} ===" hook then
      "lifecycle ok: section ${mk}"
    else
      throw ''
        pdshell loader contract violation (T31), lifecycle:
          the composed shellHook does not carry the section marker
            # === ${mk} ===
          (hookComposer.fn-assemble labels every non-empty lifecycle
          section; log navigation depends on them).

          Reconciliation:
            1. fn-assemble / fn-buildSection changed upstream — bump
               pdshell consciously
            2. the section went empty (the tree stopped declaring the
               hooks that fill it) — re-derive the marker set from the
               live hook
      '';

  # Inherited-before-own: python's language-default preShellHook
  # precedes the composing root's own, and the FINAL SHELL OVERRIDE
  # is last (it exports SHELL — anything after it would run under
  # the wrong shell).
  inheritedHook = "[preShellHook]: python shell!";
  ownHook = "[preShellHook]: default shell!";

  orderVerdict =
    if
      idxOf inheritedHook hook != -1
      && idxOf ownHook hook != -1
      && idxOf inheritedHook hook < idxOf ownHook hook
    then
      "lifecycle ok: inherited precedes own (${toString (idxOf inheritedHook hook)} < ${toString (idxOf ownHook hook)})"
    else
      throw ''
        pdshell loader contract violation (T31), lifecycle order:
          the composed PRE-SHELL section must run a language default's
          hook BEFORE the composing shell's own
            inherited: ${inheritedHook}
            own:       ${ownHook}
          (fn-composePhase: inherited ++ own — a reversed order lets
          the composer's early-exit hook shadow the languages').

          Reconciliation:
            1. fn-composePhase's concatenation order changed upstream —
               bump pdshell consciously
            2. the tree moved these sample hooks — re-derive the two
               needles from home/env/dev/{python,default}.nix
      '';

  finalOverrideNeedle = ''export SHELL="$(command -v ${shared.user.shell.tag})"'';

  finalVerdict =
    if idxOf finalOverrideNeedle hook != -1 && idxOf finalOverrideNeedle hook > idxOf ownHook hook then
      "lifecycle ok: FINAL SHELL OVERRIDE exports ${shared.user.shell.tag} (the identity axis), after every other section"
    else
      throw ''
        pdshell loader contract violation (T31), lifecycle final:
          the composed shellHook must carry the identity-axis shell
          export after the own-hook section
            ${finalOverrideNeedle}
          (observed index ${toString (idxOf finalOverrideNeedle hook)} vs
          own-hook ${toString (idxOf ownHook hook)}).

          Reconciliation:
            1. fn-applyShellOverride changed upstream — bump pdshell
               consciously
            2. the identity axis moved — shared.user.shell.tag is the
               single source and the needle re-derives from it, so a
               drift here means the export line itself changed shape
      '';

  # ── 5. NamedFile — sibling isolation ─────────────────────────────
  # python-renpy (a NamedFile sibling, no combinFrom) carries its own
  # declared inputs and does NOT leak another file's contribution:
  #   renpy         present  — renpy.nix's own declared engine
  #   python3-3.12  absent   — machine.nix's interpreter (the sibling
  #                            NamedFile's distinctive declaration)
  #   glibc         absent   — the c-family language defaults' libc
  #                            (the cross-scope class: the most
  #                            globally-declared input in the tree)
  renpyInputs = pdsh.python-renpy.buildInputs;
  renpyNames = map (x: x.name or "???") renpyInputs;

  namedFileVerdict =
    if
      builtins.any (n: hasSub "renpy" n) renpyNames
      && !builtins.any (n: hasSub "python3-3.12" n) renpyNames
      && !builtins.any (n: hasSub "glibc" n) renpyNames
    then
      "NamedFile ok: python-renpy carries renpy (${toString (builtins.length renpyInputs)} inputs), leaks neither the sibling's python3-3.12 nor the c-family's glibc"
    else
      throw ''
        pdshell loader contract violation (T31), NamedFile isolation:
          python-renpy must carry its own declared inputs and leak no
          other file's contribution (observed names:
          ${lib.concatStringsSep ", " renpyNames}).

          Reconciliation:
            1. renpy.nix dropped the renpy engine — restore it
            2. python3-3.12 present → the loader leaked machine.nix
               (the sibling NamedFile) into renpy — a loader defect,
               bump pdshell
            3. glibc present → the loader leaked a language default /
               foreign scope into the NamedFile — a loader defect,
               bump pdshell
      '';

  # ── the contract, held ─────────────────────────────────────────
  # Element order is the census short-circuit: census first, then
  # the member-specific groups (they read pdsh by name and would be
  # meaningless — or silently misdirected — under a drifted census).
  contractHeld = lib.concatStringsSep "\n" (
    [ census ]
    ++ (map faceVerdict (builtins.attrNames pdsh))
    ++ (map combinFromVerdict contributionProbes)
    ++ (map markerVerdict markers)
    ++ [
      orderVerdict
      finalVerdict
      namedFileVerdict
    ]
  );
in
{
  name = "lib_shared_pdshell";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 300;
  };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  # The contract text is spliced as a STRING EXPRESSION,
  # never into a `#` comment — contractHeld is multi-line, and only
  # the first spliced line would land behind a single '#' (the rest
  # would be bare python, which the CI driver's pylyzer run rejects
  # at the driver build).
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("pdshell: loader consumption contract — census, face, combinFrom, lifecycle, NamedFile"):
        """
        ${contractHeld}
        """
        # renders only if every group held; the machine is a dummy
        # (the contract is an eval-time property).
        machine.succeed("true")
  '';
}
