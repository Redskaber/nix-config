# @path: ~/projects/configs/nix-config/tests/module-reachability.nix
# @author: redskaber
# @datetime: 2026-10-15
# @description: tests::module-reachability — the fourth repo-hygiene gate (T41)
# @source: self (the flake source tree) × home/ + platform/ (the module trees)
#
# THE CLASS THIS GATE KILLS — dead code that no gate can see:
#   round 19 (run 38459605632 era) — home/core/srv/cache sat in the tree,
#   default.nix chain intact, but no path imported it: `cachix` never
#   reached home.packages while all 14 CI jobs were green. Evaluators
#   only see what is imported; a module that SHOULD be wired and isn't
#   is invisible to every existing gate (eval, deep-eval, VM builds,
#   docs-ssot — none of them walks the directory side of the ledger).
#   The round-19 fix wired ./cache by hand and proposed this gate.
#
# WHAT THIS GATE DOES — the directory side of the ledger, asserted:
#   1. NODES — every file under home/ and platform/ (277 at the
#      grammar-v4 landing, 276 of them .nix — the one .toml is the
#      yazi theme data; the count travels into the check output
#      so a probe regression is a visible drop, not a silent green).
#   2. MODULE DIRS — every directory containing a default.nix (the
#      unit of the assertion: 95 at the grammar-v4 landing).
#   3. ROOTS — the faces the flake actually evaluates:
#        platform/<tag>/system/default.nix
#                                        the system domain (3 tags:
#                                          darwin nixos nixos-wsl —
#                                          grammar v4, domain-explicit)
#        platform/<tag>/home/default.nix   the user domain (5 tags:
#                                          darwin linux nixos nixos-wsl
#                                          wsl — every platform owns a
#                                          home door; darwin's is
#                                          mounted by its system door
#                                          in module mode, linux/wsl
#                                          are standalone-HM-only)
#        home/env/dev                      the devShells DOMAIN root —
#                                          consumed OUTSIDE the import
#          graph: shared.nix builds devDir as a string
#          (devDir = "${shared.self}/home/env/dev") and pdshell's
#          loader walks it directory-wise (SourceKind DirectoryRoot /
#          NamedFile, mk per row); combinFrom addresses rows as
#          dev.<name>. The domain is therefore given its whole subtree
#          as a closure — row-internal wiring (which row composes into
#          which shell) is pdshell's own consumption mechanism.
#   4. EDGES — textual extraction from every node, both forms:
#        static  ./x  ../x   — resolved against the file's directory;
#                              a directory reference lands on its
#                              default.nix, a .nix file on itself.
#        dynamic ./\${…}.nix  ./\${…} — the tree's routers (app
#              categories, editors, terminals, browsers, shells,
#              drive, wm, dm) select siblings through enum rows.
#              (grammar v4 retired the arch-row routers — the arch
#              axis has no address on disk anymore; every arch
#              walks the one pipeline per platform.)
#              The gate cannot resolve an enum at scan time (that would
#              drag the whole distribution layer into a hygiene check),
#              so it over-approximates: suffix ".nix" → every sibling
#              .nix file; suffix "" → every sibling module dir and
#              .nix file. The approximation is one-directional: it can
#              only hide a dangling module (false green), never invent
#              reachability for one that is wired — a false red, the
#              unacceptable direction, is impossible for every router
#              shape the tree uses today (verified: no readDir, no
#              fileset, no path-valued let bindings, no string-concat
#              imports inside home/ or platform/).
#   5. ASSERTION — every module dir must be reachable from the roots.
#      Dangling after exemptions → the check builds RED with the
#      verbatim directory list and the reconciliation.
#   6. DOORLESS REFS (run 38632140441's class, closed 2026-10-15) —
#      static import-shaped references that name an EXISTING
#      directory under the audited trees but no module door (no
#      default.nix there). The v3→v4 grammar landing left two alive
#      by masking: tests imported platform/<tag> — the v3 top gate —
#      and evaluated green while the corpse doors still sat on disk
#      (run 38630505084's tree passed this gate's step); the corpse
#      sweep (97910e6) deleted the doors and the next eval (run
#      38632140441, testscript-syntax-check) failed on the dangling
#      reference. The discriminator is exact, both directions:
#        - a token ending in "/" is the static prefix of a dynamic
#          ./\${…} router (owned by the dynamic edge machinery —
#          never an import itself);
#        - a token whose target leaves home/ + platform/ is a data
#          binding (the hosts/ readDir census) — never an import of
#          an audited door.
#      What remains is precisely the import-shaped class; a
#      violation today always names a structural root (home/,
#      platform/, platform/<tag>/) — none of which has ever been
#      importable, so red is always stale grammar or a typo.
#
# EXEMPTIONS — the policy ledger: an entry keeps the gate green while
#   making a dangling state EXPLICIT, tracked, and self-healing. Two
#   tripwires guard the ledger itself: an exemption for a path that is
#   not a module dir is red (typo / deleted tree), and an exemption
#   for a module that has since been WIRED is red (stale — remove the
#   entry). Silent dangling becomes impossible in either direction.
#
# GATING — same shape as the other three hygiene gates (T8.1's
#   rationale): `nix flake check --no-build` only EVALUATES this
#   derivation (it always constructs fine); the assertion fires at
#   BUILD time, which is why CI STAGE 1 builds this check explicitly
#   right after pre-commit-check, docs-ssot-check, and
#   testscript-syntax-check, deep-eval Face 3 forces its drvPath, and
#   Face 4's owned list names it.
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
    elem
    elemAt
    filter
    head
    isString
    length
    listToAttrs
    pathExists
    readDir
    readFile
    readFileType
    split
    tail
    ;
  inherit (lib)
    concatLists
    concatStringsSep
    hasPrefix
    hasSuffix
    init
    removePrefix
    ;

  # ── string-land border ─────────────────────────────────────────────
  # Paths carry context since Nix 2.18 (flake self especially), and pure
  # eval rejects context-carrying strings at the file-reading builtins
  # (readDir/readFile/pathExists — the exact error this gate hit on
  # first eval: "string '…/home/core/base/default.nix' is not allowed
  # to refer to a store path"). Every crossing from path-land into
  # string-land therefore strips the context ONCE, here: the scan
  # reads the materialised flake source (already in the store), so
  # discarding is semantically sound — nothing read can depend on an
  # unbuilt derivation. Downstream strings are all derived from these
  # two borders and stay context-free.
  str = p: builtins.unsafeDiscardStringContext (toString p);

  src = dirOf (str (self + "/home"));
  trees = [
    "home"
    "platform"
  ];

  # ── 1. nodes: every .nix file under the audited trees ──────────────────
  allNix = map str (
    lib.concatLists (map (t: lib.filesystem.listFilesRecursive (self + ("/" + t))) trees)
  );

  # ── 2. module dirs: the unit of the assertion ──────────────────────
  moduleDirs = map (p: dirOf p) (filter (p: baseNameOf p == "default.nix") allNix);

  # ── 3. roots: the faces the flake evaluates ────────────────────────
  platformTagDirs = attrNames (readDir (src + "/platform"));
  systemRoots = filter (p: pathExists p) (
    map (tag: src + "/platform/" + tag + "/system/default.nix") platformTagDirs
  );
  homeRoots = filter (p: pathExists p) (
    map (tag: src + "/platform/" + tag + "/home/default.nix") platformTagDirs
  );

  # The devShells domain (see header): subtree closure by fiat.
  devDomain = src + "/home/env/dev";
  domainRoots = [ (devDomain + "/default.nix") ];
  domainClosure = filter (d: hasPrefix (devDomain + "/") d) moduleDirs;

  roots = systemRoots ++ homeRoots ++ domainRoots;

  # ── 4. edges: textual extraction, static + dynamic ────────────────
  staticPattern = "([.]{1,2}/[A-Za-z0-9._/-]+)";
  dynPattern = "([.]{1,2}/[$][{][^}]*[}][A-Za-z0-9._-]*)";

  splitSlash = s: lib.splitString "/" s;

  # resolve "./x" | "../x" against fromDir; returns a normalized
  # absolute string (.. folded). The store root folds to "" segments
  # harmlessly — nothing above the flake source passes the tree filter.
  resolve =
    fromDir: token:
    let
      go =
        dir: segs:
        if segs == [ ] then
          dir
        else if head segs == "." then
          go dir (tail segs)
        else if head segs == ".." then
          go (concatStringsSep "/" (init (splitSlash dir))) (tail segs)
        else
          go (dir + "/" + head segs) (tail segs);
    in
    go fromDir (splitSlash token);

  inTree = p: hasPrefix (src + "/home/") p || hasPrefix (src + "/platform/") p;

  # one static token → zero or one edge (dir → its default.nix, file → itself)
  staticEdge =
    fromDir: tok:
    let
      t = resolve fromDir tok;
    in
    if !(inTree t) then
      null
    else if pathExists (t + "/default.nix") then
      t + "/default.nix"
    else if hasSuffix ".nix" t && pathExists t then
      t
    else
      null;

  # the suffix after '}' of a dynamic token ("./\${x}.nix" → ".nix")
  dynSuffix =
    tok:
    let
      parts = lib.splitString "}" tok;
    in
    if length parts >= 2 then elemAt parts (length parts - 1) else "";

  # one dynamic token → the sibling over-approximation (see header §4)
  dynEdges =
    fromDir: tok:
    let
      sfx = dynSuffix tok;
      names = attrNames (readDir fromDir);
      of =
        name:
        let
          cand = fromDir + "/" + name;
        in
        if sfx == ".nix" then
          (
            if pathExists (cand + "/default.nix") then
              cand + "/default.nix"
            else if hasSuffix ".nix" cand && pathExists cand then
              cand
            else
              null
          )
        else if sfx == "" then
          (
            # bare ./\${x}: a directory OR a file row
            if pathExists (cand + "/default.nix") then
              cand + "/default.nix"
            else if hasSuffix ".nix" cand && pathExists cand then
              cand
            else
              null
          )
        else
          null; # non-.nix suffix: none in the tree; conservative skip
    in
    map of names;

  # Comments are not wiring: a comment that MENTIONS ./cache (round
  # 19's fix note does, verbatim) must not masquerade as reachability —
  # the gate's own verification-matrix control B caught exactly this
  # on first delivery (green with the import removed but the comment
  # present). Stripping both comment forms can only REMOVE candidate
  # edges, never add one: real imports in these trees are bare path
  # literals or dynamic ./\${…} forms (verified: no string-concat, no
  # quoted-path imports), so the strip never eats a real edge — what
  # it eats are the extraction's two comment-side false-green vectors
  # (paths and router shapes mentioned in notes; the tree has both).
  blockComment = "[/][*]([^*]|[*]+[^*/])*[*][/]";
  lineComment = "[#][^\n]*";
  stripRe = pat: text: concatStringsSep "" (filter isString (split pat text));

  fileEdges =
    pathStr:
    let
      text = stripRe lineComment (stripRe blockComment (readFile pathStr));
      fromDir = dirOf pathStr;
      staticToks = map (m: head m) (filter (x: !isString x) (split staticPattern text));
      dynToks = map (m: head m) (filter (x: !isString x) (split dynPattern text));
    in
    filter (e: e != null) (
      map (tok: staticEdge fromDir tok) staticToks
      ++ concatLists (map (tok: dynEdges fromDir tok) dynToks)
    );

  adj = listToAttrs (
    map (p: {
      name = p;
      value = fileEdges p;
    }) allNix
  );

  # ── reachability: worklist BFS over the import graph ───────────────
  go =
    seen: queue:
    if queue == [ ] then
      seen
    else
      let
        h = head queue;
        rest = tail queue;
      in
      if elem h seen then go seen rest else go (seen ++ [ h ]) (rest ++ (adj.${h} or [ ]));

  graphReach = go [ ] roots;

  # domain closure: every module dir under the dev domain, plus the
  # domain root file itself
  reachableFiles = graphReach ++ map (d: d + "/default.nix") domainClosure;

  # ── 5. assertion + the exemption ledger ───────────────────────────
  dangling = filter (d: !elem (d + "/default.nix") reachableFiles) moduleDirs;
  exemptions = [
    {
      path = "home/core/exp/sys/re";
      why = "the gate's FIRST CATCH (T41, 2026-10-13): added in 9440679 alongside the (wired) exp/app/re suite, but exp/sys/default.nix never imported ./re — ilspycmd on every HM host is an owner product decision (wire it / move it to the devShells domain / delete it). The entry keeps the gate green while making the dangling state explicit and tracked; wire it and this exemption turns STALE-red, forcing its own removal.";
    }
  ];

  exemptPaths = map (e: src + "/" + e.path) exemptions;

  # ledger tripwires (see header EXEMPTIONS)
  badExemptions = filter (
    p: !(elem p moduleDirs) || elem (p + "/default.nix") reachableFiles
  ) exemptPaths;

  danglingAfterExemptions = filter (d: !elem d exemptPaths) dangling;

  # ── 6. doorless directory references (header §6) ───────────────────
  # The scan domain widens for this assertion: the ORIGIN of a
  # reference can be any .nix file in the flake source (run 38632140441's
  # two lived under tests/ — outside the edge-extraction trees), only
  # the TARGET must land inside the audited trees.
  scanNix = filter (p: hasSuffix ".nix" p) (map str (lib.filesystem.listFilesRecursive self));

  inAuditedTrees =
    t:
    t == src + "/home"
    || t == src + "/platform"
    || hasPrefix (src + "/home/") t
    || hasPrefix (src + "/platform/") t;

  refToks =
    pathStr:
    let
      text = stripRe lineComment (stripRe blockComment (readFile pathStr));
    in
    map (m: head m) (filter (x: !isString x) (split staticPattern text));

  doorlessFrom =
    pathStr:
    filter (
      tok:
      let
        t = resolve (dirOf pathStr) tok;
      in
      # a trailing "/" marks the static prefix of a dynamic ./\${…}
      # router — the dynamic edge machinery owns those, never an import
      !(hasSuffix "/" tok)
      && inAuditedTrees t
      && pathExists t
      && readFileType t == "directory"
      && !(pathExists (t + "/default.nix"))
    ) (refToks pathStr);

  doorlessRefs = concatLists (
    map (
      pathStr:
      map (tok: {
        file = removePrefix (src + "/") pathStr;
        inherit tok;
        target = removePrefix (src + "/") (resolve (dirOf pathStr) tok) + "/";
      }) (doorlessFrom pathStr)
    ) scanNix
  );

  reportDoorlessRefs =
    if doorlessRefs == [ ] then
      ""
    else
      "\n"
      + concatStringsSep "\n" (
        map (r: "  - " + r.file + ": " + r.tok + " -> " + r.target + " (no default.nix)") doorlessRefs
      );

  t = toString;

  reportDangling =
    if danglingAfterExemptions == [ ] then
      ""
    else
      "\n" + concatStringsSep "\n" (map (d: "  - " + removePrefix (src + "/") d) danglingAfterExemptions);

  reportBadExemptions =
    if badExemptions == [ ] then
      ""
    else
      "\n" + concatStringsSep "\n" (map (p: "  - " + removePrefix (src + "/") p) badExemptions);
in
{
  module-reachability-check =
    pkgs.runCommand "module-reachability-check"
      {
        # Forces the three reports at eval time (a non-empty report only
        # renders when the list it summarises is non-empty — the empty
        # case is "" and costs nothing).
        inherit reportDangling reportBadExemptions reportDoorlessRefs;
        nodeCount = t (length allNix);
        moduleDirCount = t (length moduleDirs);
        rootCount = t (length roots);
        exemptCount = t (length exemptions);
        scanFileCount = t (length scanNix);
        doorlessRefCount = t (length doorlessRefs);
      }
      ''
        set -euo pipefail
        if [ -n "$reportDangling" ]; then
          echo "" >&2
          echo "module-reachability: DANGLING MODULE DIRS (no import path reaches them):$reportDangling" >&2
          echo "" >&2
          echo "Evaluators only see what is imported — these directories are invisible" >&2
          echo "to every other gate. Reconciliation, in likelihood order:" >&2
          echo "  1. wire it — add ./<name> to the parent default.nix imports list" >&2
          echo "     (check the parent first: round 19's srv/cache and this gate's" >&2
          echo "     first catch were both one-line wiring fixes)" >&2
          echo "  2. parked on purpose — add an entry to the exemption ledger in" >&2
          echo "     tests/module-reachability.nix with the why (explicit policy," >&2
          echo "     not silent dangling)" >&2
          echo "  3. dead tree — delete it" >&2
          exit 1
        fi
        if [ -n "$reportBadExemptions" ]; then
          echo "" >&2
          echo "module-reachability: STALE/INVALID EXEMPTION (wired since, or not a module dir):$reportBadExemptions" >&2
          echo "" >&2
          echo "The exemption ledger self-heals: an entry for a module that has since" >&2
          echo "been wired (or for a path that is no longer a module dir) is itself a" >&2
          echo "defect — remove the entry so the gate speaks the truth." >&2
          exit 1
        fi
        if [ -n "$reportDoorlessRefs" ]; then
          echo "" >&2
          echo "module-reachability: DOORLESS DIRECTORY REFERENCES (import-shaped, naming no module door):$reportDoorlessRefs" >&2
          echo "" >&2
          echo "A directory import resolves to <dir>/default.nix — these targets carry none." >&2
          echo "Run 38632140441's class: v3 top-gate imports survived grammar v4 masked by" >&2
          echo "the corpse doors on disk; the sweep deleted the doors and the reference" >&2
          echo "dangled into eval. Reconciliation:" >&2
          echo "  1. point it at the door it means — grammar v4 moved the system door to" >&2
          echo "     platform/<tag>/system (append /system, or /home for the user domain)" >&2
          echo "  2. dead reference — delete it" >&2
          exit 1
        fi
        mkdir -p "$out"
        echo "module-reachability: $moduleDirCount module dirs reachable from $rootCount roots (+devShells domain), $exemptCount exemptions, $nodeCount nodes scanned (static+dynamic edge extraction), $scanFileCount files scanned for doorless refs ($doorlessRefCount found)" > "$out/summary"
        cat "$out/summary"
      '';
}
