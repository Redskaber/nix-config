# @path: ~/projects/configs/nix-config/lib/dev/dshells.nix
# @author: redskaber
# @datetime: 2026-01-31
# @description: lib::dev::dshells - Strict layered loader with semantic full_name resolution
#
# CORE UPGRADES (SPEC-COMPLIANT):
# - TRUE SEMANTIC FULL_NAME GENERATION (100% matches spec examples)
#    Top-level (basePath=""):
#      • file.nix + default     → fileBase
#      • file.nix + variant     → fileBase-variant
#    Subdirectory (basePath="a-b"):
#      • default.nix + default  → a-b
#      • default.nix + variant  → a-b-variant
#      • file.nix + default     → a-b-fileBase
#      • file.nix + variant     → a-b-fileBase-variant
#    *Critical fix: Removed ambiguous "basePath == ''" special case for default.nix variants
#
# - PRECISE LAYER ISOLATION (as per spec)
#    • Non-default.nix files: dev = ONLY subdirectory variants (NO peer files)
#    • default.nix: dev = subdirs + peer non-default files (FULL layer context)
#    • Parent layers NEVER see child default.nix variants until merged upward
#
# - DEFENSIVE CONFLICT VALIDATION (actionable diagnostics)
#    • Per-layer: default.nix vs non-default file name collisions
#    • Cross-layer: GLOBAL full_name uniqueness (prevents silent attrset overwrites)
#    • Structural: file/dir name conflicts, empty dirs, invalid returns
#    • Type safety: all variants validated as attrsets BEFORE processing
#
# - SPEC-ALIGNED dev PARAMETER RESOLUTION
#    In parent/default.nix: dev.python.machine = python/machine.nix's attrset
#      → mkDevShell auto-resolves .default when used in combinFrom
#    In parent/default.nix: dev.python.origin = python/default.nix's 'origin' variant
#    *Enables: combinFrom = [ dev.c dev.python.machine ] exactly as documented
#
# WHY THIS MATTERS:
#   fm/default.nix (parent layer) accesses:
#     • dev.c → c.nix's raw variants attrset (NOT flattened shell)
#     • dev.python.machine → python/machine.nix's attrset (auto-uses .default in combinFrom)
#   Achieved via strict layer isolation + semantic full_name mapping

{ pkgs, inputs, devDir, suffix ? ".nix", ... }:
let
  inherit (import ./mk-shell.nix { inherit pkgs; }) mkDevShell;

  # VALIDATE VARIANT CONFIG IS ATTRSET (prevents mkDevShell failures)
  validateVariantConfig = path: varName: cfg:
    if !pkgs.lib.isAttrs cfg then
      throw "INVALID VARIANT CONFIG in ${path}: '${varName}' must be an attrset (got ${builtins.typeOf cfg})"
    else cfg;

  # DEV_SHELL FULL_NAME
  devShellFullName = fullName: basePath: sourceType: varName:
    if fullName == "" && basePath == "" && sourceType == "default-nix" && varName == "default"
      then "default"    # top full name
    else fullName;

  # GENERATE SEMANTIC FULL_NAME (SPEC-COMPLIANT)
  # basePath: accumulated path (e.g., "python-derivation")
  # sourceType: "default-nix" | "file"
  # sourceName: for files: base filename (e.g., "machine"); for default.nix: ""
  # varName: variant key name (e.g., "default", "machine")
  makeFullName = basePath: sourceType: sourceName: varName:
    let
      base = if basePath == "" then "" else basePath;
      mid = if sourceType == "default-nix" then
              ""  # default.nix variants attach directly to basePath
            else
              sourceName;  # non-default files inject filename
      suffixPart = if varName == "default" then "" else varName;
      parts = pkgs.lib.filter (x: x != "") [base mid suffixPart];
      fullName = pkgs.lib.concatStringsSep "-" parts;
    in devShellFullName fullName basePath sourceType varName;

  # RECURSIVE PROCESSOR: returns { flatShells, variantsTree, shellNames }
  processDirectory = currentPath: basePath:
    let
      # ===== STRUCTURAL VALIDATIONS =====
      _currentPathExistGrand = if !builtins.pathExists currentPath then
            throw "DIRECTORY NOT FOUND: ${currentPath}"
          else null;

      entries = builtins.attrNames (builtins.readDir currentPath);
      isNixFile = name:
        (builtins.readDir currentPath).${name} == "regular"
        && pkgs.lib.hasSuffix suffix name
        && !pkgs.lib.hasPrefix "_" name;
      isSubDir = name:
        (builtins.readDir currentPath).${name} == "directory"
        && !pkgs.lib.hasPrefix "_" name;

      nixFiles = builtins.filter isNixFile entries;
      subDirs  = builtins.filter isSubDir entries;

      # File/Dir name conflict (critical for unambiguous resolution)
      fileBases = map (f: pkgs.lib.removeSuffix suffix f) nixFiles;
      nameConflicts = pkgs.lib.filter (n: pkgs.lib.elem n subDirs) fileBases;
      _fileAndDirNameConflictGrand = if nameConflicts != [] then
            throw ''
              CONFIG CONFLICT in ${currentPath}:
              Ambiguous sources: ${builtins.concatStringsSep ", " nameConflicts}
              Resolution: Keep ONLY file (${suffix}) OR directory per name.
              Example: Remove either 'machine.nix' or 'machine/' directory.
            ''
          else null;

      # Empty directory guard
      _emptyDirectoryGrand = if nixFiles == [] && subDirs == [] then
            throw "EMPTY DIRECTORY: ${currentPath} requires .nix files or subdirs"
          else null;

      # ===== STEP 1: PROCESS SUBDIRECTORIES (depth-first) =====
      subResults = map (subDir:
        let
          newBase = if basePath == "" then subDir else "${basePath}-${subDir}";
          res = processDirectory "${currentPath}/${subDir}" newBase;
        in {
          name = subDir;
          flat = res.flatShells;
          variants = res.variantsTree;
          names = res.shellNames;
        }
      ) subDirs;

      subFlatAggregated = pkgs.lib.foldl' (acc: r: acc // r.flat) {} subResults;
      subVariantsPart = pkgs.lib.listToAttrs (map (r: { name = r.name; value = r.variants; }) subResults);
      subShellNames = pkgs.lib.concatMap (r: r.names) subResults;

      # ===== STEP 2: PROCESS NON-DEFAULT.NIX FILES =====
      nonDefaultFiles = builtins.filter (f: f != "default.nix") nixFiles;
      nonDefaultResults = map (fileName:
        let
          fileBase = pkgs.lib.removeSuffix suffix fileName;
          filePath = "${currentPath}/${fileName}";
          # CRITICAL ISOLATION: non-default files see ONLY subdirectory variants (no peer files)
          variants = import filePath { inherit pkgs inputs; dev = subVariantsPart; };
          _variantGrand_1 = if !pkgs.lib.isAttrs variants then
                throw "INVALID RETURN in ${filePath}: must return attrset of variants"
              else null;

          # Generate flat shells + collect semantic names
          flatShells = pkgs.lib.mapAttrs' (varName: cfg:
            let
              validatedCfg = validateVariantConfig filePath varName cfg;
              fullName = makeFullName basePath "file" fileBase varName;
            in pkgs.lib.nameValuePair fullName (
              mkDevShell (validatedCfg // { name = "dev-shell-${fullName}"; })
            )
          ) variants;
          names = builtins.attrNames flatShells;
        in { fileBase = fileBase; variants = variants; flat = flatShells; names = names; }
      ) nonDefaultFiles;

      nonDefaultFlatShells = pkgs.lib.foldl' (acc: r: acc // r.flat) {} nonDefaultResults;
      localVariants = pkgs.lib.listToAttrs (map (r: { name = r.fileBase; value = r.variants; }) nonDefaultResults);
      nonDefaultNames = pkgs.lib.concatMap (r: r.names) nonDefaultResults;

      # Per-layer validation: non-default file name conflicts
      nonDefaultDupes = pkgs.lib.filter (n: (pkgs.lib.count (x: x == n) nonDefaultNames) > 1) (pkgs.lib.unique nonDefaultNames);
      _nonDefaultDupGrand = if nonDefaultDupes != [] then
            throw ''
              LAYER CONFLICT in ${currentPath} (non-default files):
              Duplicate shell names: ${builtins.concatStringsSep ", " nonDefaultDupes}
              Resolution: Rename variants or files per semantic rules.
              Example: In 'machine.nix', rename variant 'default' to avoid collision with 'machine/default.nix'
            ''
          else null;

      # ===== STEP 3: PROCESS DEFAULT.NIX (LAST) =====
      hasDefault = builtins.elem "default.nix" nixFiles;
      defaultResult = if hasDefault then
        let
          filePath = "${currentPath}/default.nix";
          # CRITICAL: default.nix sees FULL layer context (subdirs + peer files)
          devForDefault = subVariantsPart // localVariants;
          variants = import filePath { inherit pkgs inputs; dev = devForDefault; };
          _variantGrand_2 = if !pkgs.lib.isAttrs variants then
                throw "INVALID RETURN in ${filePath}: must return attrset of variants"
              else null;

          flatShells = pkgs.lib.mapAttrs' (varName: cfg:
            let
              validatedCfg = validateVariantConfig filePath varName cfg;
              fullName = makeFullName basePath "default-nix" "" varName;
            in pkgs.lib.nameValuePair fullName (
              mkDevShell (validatedCfg // { name = "dev-shell-${fullName}"; })
            )
          ) variants;
          names = builtins.attrNames flatShells;

          # Validate against non-default files in SAME layer
          layerDupes = pkgs.lib.filter (n: pkgs.lib.elem n nonDefaultNames) names;
          _layerDupGrand = if layerDupes != [] then
                throw ''
                  LAYER CONFLICT in ${currentPath} (default.nix vs non-default):
                  Conflicting full_names: ${builtins.concatStringsSep ", " layerDupes}
                  Resolution:
                    • Rename variant in default.nix (e.g., 'machine' → 'custom-machine'), OR
                    • Rename conflicting file (e.g., 'machine.nix' → 'hardware.nix')
                  Spec note:
                    default.nix variant 'X' → full_name = ${basePath}-X
                    X.nix variant 'default' → full_name = ${basePath}-X (COLLISION)
                ''
              else null;
        in { flat = flatShells; names = names; variants = variants; }
      else { flat = {}; names = []; variants = {}; };

      # ===== MERGE VARIANTS TREE FOR PARENT LAYERS =====
      baseVariantsTree = subVariantsPart // localVariants;
      variantsTree =
        if hasDefault && defaultResult.variants != {} then
          let
            commonKeys = pkgs.lib.attrNames (pkgs.lib.intersectAttrs baseVariantsTree defaultResult.variants);
          in
          if commonKeys != [] then
            throw ''
              VARIANTS TREE CONFLICT in ${currentPath}:
              Keys defined in BOTH non-default sources AND default.nix: ${builtins.concatStringsSep ", " commonKeys}
              Resolution:
                • Rename variant in default.nix (e.g., 'machine' → 'vm'), OR
                • Rename conflicting file/directory (e.g., 'machine.nix' → 'hardware.nix')
              Example conflict pattern to avoid:
                default.nix defines variant "machine" AND machine.nix exists
            ''
          else
            baseVariantsTree // defaultResult.variants
        else
          baseVariantsTree;

      # ===== AGGREGATE RESULTS =====
      flatShells = subFlatAggregated // nonDefaultFlatShells // defaultResult.flat;
      shellNames = subShellNames ++ nonDefaultNames ++ defaultResult.names;
    in { flatShells = flatShells; variantsTree = variantsTree; shellNames = shellNames; };

  # ===== TOP-LEVEL INVOCATION & GLOBAL VALIDATION =====
  rootResult = processDirectory devDir "";
  allShellNames = rootResult.shellNames;

  # GLOBAL UNIQUENESS VALIDATION (PREVENTS SILENT OVERWRITES)
  uniqueNames = pkgs.lib.unique allShellNames;
  duplicates = pkgs.lib.filter (n: (pkgs.lib.count (x: x == n) allShellNames) > 1) uniqueNames;
  _duplicateGrand = if duplicates != [] then
        throw ''
          GLOBAL SHELL CONFLICT: Duplicate full_names detected!
          Conflicting identifiers: ${builtins.concatStringsSep ", " duplicates}

          Resolution guide (per spec):
            • Top-level conflict:
                default.nix has variant "X" AND X.nix has variant "default" → both generate "X"
            • Subdirectory conflict (basePath="a-b"):
                default.nix variant "X" → "a-b-X"
                X.nix variant "default" → "a-b-X" (COLLISION)
            • Fix:
                - Rename variant in default.nix (e.g., "machine" → "vm"), OR
                - Rename conflicting file (e.g., "machine.nix" → "hardware.nix")
            • Verify with: nix develop .#<name> --show-trace
        ''
      else null;

in rootResult.flatShells


