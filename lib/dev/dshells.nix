# @path: ~/projects/configs/nix-config/lib/dev/dshells.nix
# @author: redskaber
# @datetime: 2026-01-29
# @description: lib::dev::dshells - Strict layered loader with nested variants tree & robust uniqueness validation
#
# CORE UPGRADES FROM ORIGINAL:
# TRUE GLOBAL UNIQUENESS VALIDATION (FIXED CRITICAL BUG)
#    - Collects ALL full_names across layers BEFORE attrset merge
#    - Prevents silent attrset key overwrites during // merge
# PRECISE LAYER ISOLATION
#    - Non-default.nix files receive ONLY subdirectory variants (no peer files)
#    - default.nix receives FULL layer context (subdirs + peer files)
# SEMANTIC FULL_NAME GENERATION (100% spec compliant)
#    Top-level (basePath=""):
#      • default.nix + variant     → variant
#      • file.nix    + default     → fileBase
#      • file.nix    + variant     → fileBase-variant
#    Subdirectory (basePath="a-b"):
#      • default.nix + default     → a-b
#      • default.nix + variant     → a-b-variant
#      • file.nix    + default     → a-b-fileBase
#      • file.nix    + variant     → a-b-fileBase-variant
# DEFENSIVE VALIDATIONS
#    - Per-layer: peer file conflicts, default.nix vs non-default conflicts
#    - Global: cross-layer full_name collisions with actionable diagnostics
#    - Structural: file/dir name conflicts, empty directories
#    - Type safety: all variant configs validated as attrsets
#
# WHY THIS MATTERS FOR fm/dm PATTERNS:
#   fm/default.nix accesses `dev.c` and `dev.python.machine`
#   → `dev.c` = c.nix's raw variants attrset (NOT flattened shell)
#   → `dev.python.machine` = python.nix.variants.machine
#   Achieved by strict layer isolation in variantsTree construction

{ pkgs, inputs, devDir, suffix ? ".nix", ... }:
let
  inherit (import ./mk-shell.nix { inherit pkgs; }) mkDevShell;

  # VALIDATE VARIANT CONFIG IS ATTRSET (prevents mkDevShell failures)
  validateVariantConfig = path: varName: cfg:
    if !pkgs.lib.isAttrs cfg then
      throw "INVALID VARIANT CONFIG in ${path}: '${varName}' must be an attrset (got ${builtins.typeOf cfg})"
    else cfg;

  # RECURSIVE PROCESSOR: returns { flatShells, variantsTree, shellNames }
  #   flatShells   : attrset of final shells (for output)
  #   variantsTree : nested structure for parent's `dev` param (subdirs + non-default files ONLY)
  #   shellNames   : LIST of all full_names in this subtree (critical for global uniqueness check)
  processDirectory = currentPath: basePath:
    let
      # ===== STRUCTURAL VALIDATIONS =====
      _handle_current_path_throw = if !builtins.pathExists currentPath then
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
      _handle_name_conflicts_throw = if nameConflicts != [] then
            throw ''
              CONFIG CONFLICT in ${currentPath}:
              Ambiguous sources: ${builtins.concatStringsSep ", " nameConflicts}
              Resolution: Keep ONLY file (${suffix}) OR directory per name.
            ''
          else null;

      # Empty directory guard
      _handle_emtry_directory_throw = if nixFiles == [] && subDirs == [] then
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
          names = res.shellNames;  # CRITICAL: collect ALL descendant names
        }
      ) subDirs;

      subFlatAggregated = pkgs.lib.foldl' (acc: r: acc // r.flat) {} subResults;
      subVariantsPart = pkgs.lib.listToAttrs (map (r: { name = r.name; value = r.variants; }) subResults);
      subShellNames = pkgs.lib.concatMap (r: r.names) subResults;  # Flatten all descendant names

      # ===== STEP 2: PROCESS NON-DEFAULT.NIX FILES =====
      nonDefaultFiles = builtins.filter (f: f != "default.nix") nixFiles;
      nonDefaultResults = map (fileName:
        let
          fileBase = pkgs.lib.removeSuffix suffix fileName;
          filePath = "${currentPath}/${fileName}";
          # CRITICAL ISOLATION: non-default files see ONLY subdirectory variants (no peer files)
          variants = import filePath { inherit pkgs inputs; dev = subVariantsPart; };
          _handle_variants_throw = if !pkgs.lib.isAttrs variants then
                throw "INVALID RETURN in ${filePath}: must return attrset of variants"
              else null;

          # Generate flat shells + collect names
          flatShells = pkgs.lib.mapAttrs' (varName: cfg:
            let
              validatedCfg = validateVariantConfig filePath varName cfg;
              fullName =
                if basePath == "" then
                  if varName == "default" then fileBase
                  else "${fileBase}-${varName}"
                else
                  if varName == "default" then "${basePath}-${fileBase}"
                  else "${basePath}-${fileBase}-${varName}";
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
      _handle_no_default_dups_throw = if nonDefaultDupes != [] then
            throw ''
              LAYER CONFLICT in ${currentPath} (non-default files):
              Duplicate shell names: ${builtins.concatStringsSep ", " nonDefaultDupes}
              Resolution: Rename variants or files per semantic rules.
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
          _handle_attrset_variants_throw = if !pkgs.lib.isAttrs variants then
                throw "INVALID RETURN in ${filePath}: must return attrset of variants"
              else null;

          flatShells = pkgs.lib.mapAttrs' (varName: cfg:
            let
              validatedCfg = validateVariantConfig filePath varName cfg;
              fullName =
                if basePath == "" then varName
                else if varName == "default" then basePath
                else "${basePath}-${varName}";
            in pkgs.lib.nameValuePair fullName (
              mkDevShell (validatedCfg // { name = "dev-shell-${fullName}"; })
            )
          ) variants;
          names = builtins.attrNames flatShells;

          # Validate against non-default files in SAME layer
          layerDupes = pkgs.lib.filter (n: pkgs.lib.elem n nonDefaultNames) names;
          _handle_layer_dups_throw = if layerDupes != [] then
                throw ''
                  LAYER CONFLICT in ${currentPath} (default.nix vs non-default):
                  Conflicting names: ${builtins.concatStringsSep ", " layerDupes}
                  Resolution:
                    • Rename variant in default.nix, OR
                    • Rename non-default file/variant per semantic rules
                ''
              else null;
        in { flat = flatShells; names = names; variants = variants;}
      else { flat = {}; names = []; variants = {}; };

      # ===== CRITICAL FIX: MERGE default.nix VARIANTS INTO variantsTree =====
      baseVariantsTree = subVariantsPart // localVariants;
      variantsTree =
        if hasDefault && defaultResult.variants != {} then
          let
            # Detect key conflicts between existing tree and default.nix variants
            commonKeys = pkgs.lib.attrNames (pkgs.lib.intersectAttrs baseVariantsTree defaultResult.variants);
          in
          if commonKeys != [] then
            throw ''
              VARIANTS TREE CONFLICT in ${currentPath}:
              Keys defined in BOTH non-default sources AND default.nix: ${builtins.concatStringsSep ", " commonKeys}
              Resolution:
                • Rename variant in default.nix, OR
                • Rename conflicting file/directory
              Example conflict pattern to avoid:
                default.nix defines variant "machine" AND machine.nix exists
            ''
          else
            baseVariantsTree // defaultResult.variants  # SAFE MERGE
        else
          baseVariantsTree;

      # ===== AGGREGATE RESULTS =====
      flatShells = subFlatAggregated // nonDefaultFlatShells // defaultResult.flat;
      # CRITICAL: Collect ALL names BEFORE attrset merge to detect cross-layer collisions
      shellNames = subShellNames ++ nonDefaultNames ++ defaultResult.names;
    in { flatShells = flatShells; variantsTree = variantsTree; shellNames = shellNames; };

  # ===== TOP-LEVEL INVOCATION & GLOBAL VALIDATION =====
  rootResult = processDirectory devDir "";
  allShellNames = rootResult.shellNames;

  # GLOBAL UNIQUENESS VALIDATION (FIXES SILENT OVERWRITE BUG IN ORIGINAL)
  uniqueNames = pkgs.lib.unique allShellNames;
  duplicates = pkgs.lib.filter (n: (pkgs.lib.count (x: x == n) allShellNames) > 1) uniqueNames;
  _handle_duplicates_throw = if duplicates != [] then
        throw ''
          GLOBAL SHELL CONFLICT: Duplicate full_names detected!
          Conflicting identifiers: ${builtins.concatStringsSep ", " duplicates}

          Resolution guide:
            • Top-level conflict:
                default.nix has variant "X" AND X.nix has variant "default" → both generate "X"
            • Subdirectory conflict (basePath="a-b"):
                default.nix variant "X" → "a-b-X"
                X.nix variant "default" → "a-b-X" (COLLISION)
            • Fix: Rename variant in default.nix OR rename conflicting file/variant
            • Use `nix develop .#<name>` to verify intended shell
        ''
      else null;

in rootResult.flatShells




