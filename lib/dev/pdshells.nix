# @path: ～/projects/configs/nix-config/lib/dev/dshells.nix
# @author: redskaber
# @datetime: 2026-02-02
# @description: lib::dev::dshells - Dataflow-driven layered loader with pipeline architecture

{ pkgs, inputs, devDir, suffix ? ".nix", ... }:
let
  inherit (import ./mk-shell.nix { inherit pkgs; }) mkDevShell;

  # == CORE ARCHITECTURE PATTERNS ==
  # 1. Pipeline composition: |> |> for data transformation
  # 2. Layer isolation: pure functions with explicit context
  # 3. Early validation: fail-fast at source
  # 4. Semantic naming: decoupled naming strategy

  # == PIPELINE PRIMITIVES ==
  # pipe = initial: steps: builtins.foldl' (acc: step: step acc) initial steps;

  # == VALIDATION MODULE (fail-fast at source) ==
  validate = {
    isAttrSet = path: value:
      if !pkgs.lib.isAttrs value
      then throw "INVALID STRUCTURE (${path}): Expected attrset but got ${builtins.typeOf value}"
      else value;

    uniqueNames = context: names:
      let
        dupes = pkgs.lib.filter (n: pkgs.lib.count (x: x == n) names > 1) (pkgs.lib.unique names);
      in
      if dupes != []
      then throw ''
        ${context} CONFLICT: Duplicate identifiers detected!
        Conflicting names: ${builtins.concatStringsSep ", " dupes}
        Resolution: Follow semantic naming rules:
          • default.nix variant 'X' → full_name = [base]-X
          • X.nix variant 'default' → full_name = [base]-X (COLLISION)
      ''
      else names;
  };

  # == NAMING STRATEGY MODULE (decoupled policy) ==
  naming = {
    # Unified naming pipeline with pipe operators
    makeFullName = basePath: sourceType: sourceName: variantName:
      ([
        (if basePath == "" then null else basePath)
        (if sourceType == "default-nix" then null else sourceName)
        (if variantName == "default" then null else variantName)
      ]
      |> pkgs.lib.filter (x: x != null))                              # Remove empty parts
      |> pkgs.lib.concatStringsSep "-"                                # Join with hyphens
      |> (fullName: if fullName == "" then "default" else fullName);  # Handle empty case
  };

  # == FILESYSTEM MODULE (pure path operations) ==
  fs = {
    listEntries = dir: builtins.attrNames (builtins.readDir dir);

    isNixFile = dir: name:
      let type = (builtins.readDir dir).${name};
      in type == "regular" && pkgs.lib.hasSuffix suffix name && !pkgs.lib.hasPrefix "_" name;

    isSubDir = dir: name:
      let type = (builtins.readDir dir).${name};
      in type == "directory" && !pkgs.lib.hasPrefix "_" name;

    ensureExists = path:
      if !builtins.pathExists path
      then throw "PATH NOT FOUND: ${path}"
      else path;
  };

  # == LAYER PROCESSING MODULE (isolated context) ==
  layer = {
    # Process subdirectories FIRST (depth-first)
    processSubdirs = currentPath: basePath: ctx:
      let
        subDirs = fs.listEntries currentPath |> pkgs.lib.filter (fs.isSubDir currentPath);
        subResults = map (subDir:
          let
            newBase = if basePath == "" then subDir else "${basePath}-${subDir}";
            res = layer.processDirectory "${currentPath}/${subDir}" newBase;
          in {
            name = subDir;
            flat = res.flatShells;
            variants = res.variantsTree;
            names = res.shellNames;
          }
        ) subDirs;

        flatShells = pkgs.lib.foldl' (acc: r: acc // r.flat) {} subResults;
        variantsTree = pkgs.lib.listToAttrs (map (r: { name = r.name; value = r.variants; }) subResults);
        shellNames = pkgs.lib.concatMap (r: r.names) subResults;
      in ctx // {
        subdirs = {
          flatShells = flatShells;
          variantsTree = variantsTree;
          shellNames = shellNames;
        };
      };

    # Process non-default files (isolated context: sees ONLY subdirs)
    processNonDefault = currentPath: basePath: ctx:
      let
        nixFiles = fs.listEntries currentPath
          |> pkgs.lib.filter (fs.isNixFile currentPath)
          |> pkgs.lib.filter (name: name != "default.nix");

        fileResults = map (fileName:
          let
            fileBase = pkgs.lib.removeSuffix suffix fileName;
            filePath = "${currentPath}/${fileName}";
            # CRITICAL ISOLATION: non-default files see ONLY subdirectory variants
            variants = import filePath {
              inherit pkgs inputs;
              dev = ctx.subdirs.variantsTree;
            } |> validate.isAttrSet filePath;

            flatShells = pkgs.lib.mapAttrs' (varName: cfg:
              let
                fullName = naming.makeFullName basePath "file" fileBase varName;
                shell = mkDevShell (cfg // { name = "dev-shell-${fullName}"; });
              in { name = fullName; value = shell; }
            ) variants;

            shellNames = builtins.attrNames flatShells;
          in {
            fileBase = fileBase;
            variants = variants;
            flatShells = flatShells;
            shellNames = shellNames;
          }
        ) nixFiles;

        # Validate intra-layer collisions
        localNames = pkgs.lib.concatMap (r: r.shellNames) fileResults;
        _ = validate.uniqueNames "NON-DEFAULT FILES" (ctx.shellNames ++ localNames);

        flatShells = pkgs.lib.foldl' (acc: r: acc // r.flatShells) {} fileResults;
        variantsTree = pkgs.lib.listToAttrs (map (r: { name = r.fileBase; value = r.variants; }) fileResults);
        shellNames = ctx.shellNames ++ localNames;
      in ctx // {
        nonDefault = {
          flatShells = flatShells;
          variantsTree = variantsTree;
          shellNames = shellNames;
        };
        # Update context for next stage
        shellNames = shellNames;
        variantsTree = ctx.subdirs.variantsTree // variantsTree;
      };

    # Process default.nix LAST (full context: subdirs + non-default files)
    processDefault = currentPath: basePath: ctx:
      let
        hasDefault = pkgs.lib.any (name: name == "default.nix") (fs.listEntries currentPath);
      in if !hasDefault then ctx else
        let
          filePath = "${currentPath}/default.nix";
          # FULL CONTEXT: sees subdirs AND non-default files
          variants = import filePath {
            inherit pkgs inputs;
            dev = ctx.variantsTree;
          } |> validate.isAttrSet filePath;

          flatShells = pkgs.lib.mapAttrs' (varName: cfg:
            let
              fullName = naming.makeFullName basePath "default-nix" "" varName;
              shell = mkDevShell (cfg // { name = "dev-shell-${fullName}"; });
            in { name = fullName; value = shell; }
          ) variants;

          shellNames = builtins.attrNames flatShells;

          # Validate against existing names in THIS LAYER
          _validate_unique_name_ = validate.uniqueNames "DEFAULT.NIX" (ctx.shellNames ++ shellNames);

          # Merge into variants tree (prevent key collisions)
          mergedVariants = ctx.variantsTree // variants;
          _variant_tree_conflict_ = if pkgs.lib.attrNames ctx.variantsTree != pkgs.lib.attrNames mergedVariants
            then throw ''
              VARIANTS TREE CONFLICT in ${currentPath}:
              Keys overlap between default.nix and existing sources.
              Resolution: Rename variants in default.nix or rename conflicting files/dirs.
            ''
            else null;
        in ctx // {
          default = {
            flatShells = flatShells;
            shellNames = shellNames;
            variants = variants;
          };
          # Final layer state
          flatShells = ctx.flatShells // flatShells;
          variantsTree = mergedVariants;
          shellNames = ctx.shellNames ++ shellNames;
        };

    # Main directory processor (pipeline architecture)
    processDirectory = currentPath: basePath:
      fs.ensureExists currentPath
      |> (path: {
        # Initial context
        flatShells = {};
        variantsTree = {};
        shellNames = [];
        currentPath = path;
        basePath = basePath;
      })
      |> (ctx:
        # Structural validation
        let entries = fs.listEntries ctx.currentPath;
            nixFiles = pkgs.lib.filter (fs.isNixFile ctx.currentPath) entries;
            subDirs = pkgs.lib.filter (fs.isSubDir ctx.currentPath) entries;
            fileBases = map (f: pkgs.lib.removeSuffix suffix f) nixFiles;
            conflicts = pkgs.lib.filter (n: pkgs.lib.elem n subDirs) fileBases;
        in if conflicts != []
          then throw ''
            STRUCTURAL CONFLICT in ${ctx.currentPath}:
            Ambiguous sources: ${builtins.concatStringsSep ", " conflicts}
            Resolution: Keep ONLY file (${suffix}) OR directory per base name.
          ''
          else if nixFiles == [] && subDirs == []
          then throw "EMPTY DIRECTORY: ${ctx.currentPath} requires .nix files or subdirs"
          else ctx
      )
      |> (layer.processSubdirs currentPath basePath)
      |> (layer.processNonDefault currentPath basePath)
      |> (layer.processDefault currentPath basePath)
      # Final layer state
      |> (ctx: {
        flatShells = ctx.flatShells // ctx.subdirs.flatShells // ctx.nonDefault.flatShells;
        variantsTree = ctx.variantsTree;
        shellNames = ctx.shellNames;
      });
  };

  # == TOP-LEVEL EXECUTION ==
  rootResult = layer.processDirectory devDir "";

  # Global uniqueness validation (fail-fast before derivation)
  _ = validate.uniqueNames "GLOBAL NAMESPACE" rootResult.shellNames;

in rootResult.flatShells


