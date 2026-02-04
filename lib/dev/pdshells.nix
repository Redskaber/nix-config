# @path: ～/projects/configs/nix-config/lib/dev/dshells.nix
# @author: redskaber
# @datetime: 2026-02-02
# @description: lib::dev::dshells - Dataflow-driven layered loader with pipeline architecture
# - Pipeline and Dataflow and Currying

{ pkgs, inputs, devDir, suffix ? ".nix", ... }:
let
  inherit (import ./mk-shell.nix { inherit pkgs; }) mkDevShell;

  # == VALIDATION MODULE (pipeline-optimized) ==
  validate = {
    # Pipeline-friendly validation primitives (curried)

    # @context: string
    # @value: any
    assertAttrSet = context: value:
      if pkgs.lib.isAttrs value then value else throw ''
        INVALID STRUCTURE (${context}):
        • Expected: attrset
        • Got: ${builtins.typeOf value}
        Resolution: Ensure file returns an attrset like:
          { default = { buildInputs = [ ... ]; }; }
      '';

    # @context: string
    # @names: [ string ]
    assertUniqueNames = context: names:
      (pkgs.lib.unique names)
      |> (uniqueNames: pkgs.lib.filter (n: pkgs.lib.count (x: x == n) names > 1) uniqueNames)
      |> (dupes: if dupes == [] then names else throw ''
          ${context} NAMING CONFLICT:
          • Duplicate identifiers: ${builtins.concatStringsSep ", " dupes}
          Resolution: Follow naming protocol:
            - default.nix variant 'X' → [base]-X
            - X.nix variant 'default' → [base]-X (AVOID if [base]-X exists)
          Fix by renaming variants/files for global uniqueness.
        '');

    # @path: string
    assertFileExists = path:
      if builtins.pathExists path then path else throw ''
        PATH NOT FOUND: ${path}
        Resolution: Verify directory structure matches expectations.
      '';

    # Pipeline checker
    # @context: string
    # @base: {...}
    # @new: {...}
    # @ctx: Context
    assertNoKeyConflicts = context: base: new: ctx:
      (builtins.attrNames new)
      |> (newKeys: pkgs.lib.filter (key: pkgs.lib.hasAttr key base) newKeys)
      |> (conflicts: if conflicts == [] then ctx else throw ''
          ${context} KEY COLLISION:
          • Conflicting keys: ${builtins.concatStringsSep ", " conflicts}
          • Base keys: ${builtins.concatStringsSep ", " (builtins.attrNames base)}
          • New keys: ${builtins.concatStringsSep ", " (builtins.attrNames new)}
          Resolution: Rename variants in default.nix or conflicting files/dirs.
        '');

    # Prevent key collisions in variants tree
    # @ctx: Context
    assertDefaultAttrsConflicts = ctx:
      (ctx.subDirsAttrs.variantsTree // ctx.commonAttrs.variantsTree)
      |> (variantsTree: validate.assertNoKeyConflicts "VARIANTS TREE" variantsTree ctx.defaultAttrs.variantsTree ctx);

    # Structural validation pipeline
    # @ctx: Context
    assertStructuralValidation = ctx:
      let
        entries = fs.listEntries ctx.currentPath;
        nixFiles = entries |> (e: pkgs.lib.filter (fs.isAttrsFile ctx.currentPath ctx.suffix) e);
        subDirs = entries |> (e: pkgs.lib.filter (fs.isSubDir ctx.currentPath) e);
        fileBases = nixFiles |> (files: map (f: pkgs.lib.removeSuffix ctx.suffix f) files);
        conflicts = fileBases |> (bases: pkgs.lib.filter (n: pkgs.lib.elem n subDirs) bases);
      in if conflicts == [] then ctx else throw ''
          STRUCTURAL AMBIGUITY in ${ctx.currentPath}:
          • Conflicting sources: ${builtins.concatStringsSep ", " conflicts}
          Resolution: Maintain ONE source per base name:
            - EITHER file (${ctx.suffix}) OR directory
            - NOT both ${builtins.concatStringsSep " AND " (map (name: "${name}${ctx.suffix} vs ${name}/") conflicts)}
          ''
        |> (ctx: if nixFiles == [] && subDirs == [] then
          throw "EMPTY DIRECTORY: ${ctx.currentPath} requires .nix files or subdirs"
          else ctx);
  };

  # == CORE ARCHITECTURE PATTERNS ==
  # 1. Pipeline composition: |> for data transformation
  # 2. Layer isolation: pure functions with explicit context
  # 3. Early validation: fail-fast at source
  # 4. Semantic naming: decoupled naming strategy

  # == NAMING STRATEGY MODULE ==
  naming = {
    # Unified naming pipeline with pipe operators
    # @basePath: string
    # @attrType: enum::AttrType
    # @fileBase: string
    # @variantName: string
    makeFullName = basePath: attrType: fileBase: variantName:
      ([
        (if basePath == "" then null else basePath)
        (if attrType == fs.AttrType.Default then null else fileBase)
        (if variantName == "default" then null else variantName)
      ]
      |> pkgs.lib.filter (x: x != null))                              # Remove empty parts
      |> pkgs.lib.concatStringsSep "-"                                # Join with hyphens
      |> (fullName: if fullName == "" then "default" else fullName);  # Handle empty case
  };

  # == FILESYSTEM MODULE (pure path operations) ==
  fs = {
    # Since Nix lacks native support for data structures,
    # we utilize native datasets and employ a contract-based approach to simulate enums,
    # aiming for clearer semantic expression.
    AttrType = {
      Default = 0;
      Common  = 1;
    };

    # Curried type checkers (pipeline-ready)
    isPrivate = name: (pkgs.lib.hasPrefix "_" name);
    isNixFile = suffix: name: (pkgs.lib.hasSuffix suffix name);

    isType = expectedType: path: name:
      (builtins.readDir path).${name}
      |>(type: type == expectedType);

    isRegular = fs.isType "regular";
    isDirectory = fs.isType "directory";
    isSubDir = path: name:
      (fs.isDirectory path name)
      && !fs.isPrivate name;
    isAttrsFile = path: suffix: name:
      (fs.isRegular path name)
      && fs.isNixFile suffix name
      && !fs.isPrivate name;

    listEntries = path:
      builtins.readDir path
      |> builtins.attrNames;

    # High-level directory scanners (optimized pipelines)
    listSubDirs = path:
      (fs.listEntries path)
      |> (entries: pkgs.lib.filter (name: fs.isSubDir path name) entries);
    listAttrsFiles = path: suffix:
      (fs.listEntries path)
      |> (entries: pkgs.lib.filter (name: name != "default.nix" && fs.isAttrsFile path suffix name) entries);

    hasDefaultAttrs = path:
      (fs.listEntries path)
      |> (entries: pkgs.lib.any (name: name == "default.nix") entries);

  };


  # == LAYER PROCESSING MODULE ==
  layer = {
    # Since Nix lacks native support for data structures,
    # we simulate structs using its native function capabilities
    # to achieve a visual representation of the internal data.

    # Common layer attrs schema
    # @flatShells:   { shellName<string> : Shell<derivation> }
    # @variantsTree: { sublayer::variantsTree<string, attrset>, commonAttrsets<string, attrset>, defaultAttrsets<string, attrset> }
    # @shellNames:   { shellNames<string> }
    CommonAttrs = {
      flatShells ? {},
      variantsTree ?{},
      shellNames ? []
    }: {
      flatShells = flatShells;
      variantsTree = variantsTree;
      shellNames = shellNames;
    };
   # Context attrs schema
    Context = {
      currentPath,
      basePath,
      suffix ? ".nix",
      subDirsAttrs ? layer.CommonAttrs {},
      commonAttrs ? layer.CommonAttrs {},
      defaultAttrs ? layer.CommonAttrs {}
    }: {
      currentPath = currentPath;
      basePath = basePath;
      suffix = suffix;
      subDirsAttrs = subDirsAttrs;
      commonAttrs = commonAttrs;
      defaultAttrs = defaultAttrs;
    };

    # Initial Context Function Callable
    initialContext = currentPath: basePath: suffix:
      (layer.Context { currentPath=currentPath; basePath=basePath; suffix=suffix; });

    # Process subdirectories FIRST (depth-first)
    processSubdirsAttrs = currentPath: basePath: ctx:
      let
        subDirPaths = fs.listSubDirs currentPath;
        subResults = map (path:
          let
            newBasePath = if basePath == "" then path else "${basePath}-${path}";
            res = layer.processDirectory "${currentPath}/${path}" newBasePath;
          in {
            name = path;
            flatShells = res.flatShells;
            variantsTree = res.variantsTree;
            shellNames = res.shellNames;
          }
        ) subDirPaths;

        flatShells = pkgs.lib.foldl' (acc: r: acc // r.flatShells) {} subResults;
        variantsTree = pkgs.lib.listToAttrs (map (r: { name = r.name; value = r.variantsTree; }) subResults);
        shellNames = (pkgs.lib.concatMap (r: r.shellNames) subResults)
          |> (names: validate.assertUniqueNames "SUB DIRECTORY ATTRS" names);
      in ctx // {
        subDirsAttrs = {
          flatShells = flatShells;
          variantsTree = variantsTree;
          shellNames = shellNames;
        };
      };

    # Process non-default files (common attrs files, isolated context: sees ONLY subdirs)
    processCommonAttrs = currentPath: basePath: ctx:
      let
        attrsFiles = fs.listAttrsFiles currentPath suffix;
        fileResults = map (fileName:
          let
            fileBase = pkgs.lib.removeSuffix suffix fileName;
            filePath = "${currentPath}/${fileName}";
            # CRITICAL ISOLATION: non-default files see ONLY subdirectory variants
            variantsTree = (import filePath {
                inherit pkgs inputs;
                dev = ctx.subDirsAttrs.variantsTree;
              }) |> (vars: validate.assertAttrSet filePath vars);  # Validation in pipeline

            flatShells = pkgs.lib.mapAttrs' (variantName: attrsetCfg:
                let
                  fullName = naming.makeFullName basePath fs.AttrType.Common fileBase variantName;
                  shell = mkDevShell (attrsetCfg // { name = "dev-shell-${fullName}"; });
                in { name = fullName; value = shell; }
              ) variantsTree;

            shellNames = builtins.attrNames flatShells;
          in {
            fileBase = fileBase;
            flatShells = flatShells;
            variantsTree = variantsTree;
            shellNames = shellNames;
          }
        ) attrsFiles;

        # Validate intra-layer collisions via pipeline
        variantsTree = pkgs.lib.listToAttrs (map (r: { name = r.fileBase; value = r.variantsTree; }) fileResults);
        flatShells = pkgs.lib.foldl' (acc: r: acc // r.flatShells) {} fileResults;
        shellNames = (pkgs.lib.concatMap (r: r.shellNames) fileResults)
          |> (names: validate.assertUniqueNames "COMMON ATTRS FILES" names);
      in ctx // {
        commonAttrs = {
          flatShells = flatShells;
          variantsTree = variantsTree;
          shellNames = shellNames;
        };
      };

    # Process default.nix LAST (default attrs file, full context: subdirs + non-default files)
    processDefaultAttrs = currentPath: basePath: ctx:
      if !(fs.hasDefaultAttrs currentPath) then ctx else
        let
          fileBase = "";
          filePath = "${currentPath}/default.nix";
          # FULL CONTEXT: sees subdirs AND non-default files
          variantsTree = (import filePath {
              inherit pkgs inputs;
              dev = ctx.subDirsAttrs.variantsTree // ctx.commonAttrs.variantsTree;  # Full context
            }) |> (vars: validate.assertAttrSet filePath vars);  # Pipeline validation

          flatShells = pkgs.lib.mapAttrs' (variantName: attrsetCfg:
              let
                fullName = naming.makeFullName basePath fs.AttrType.Default fileBase variantName;
                shell = mkDevShell (attrsetCfg // { name = "dev-shell-${fullName}"; });
              in { name = fullName; value = shell; }
            ) variantsTree;

          shellNames = builtins.attrNames flatShells
            |> (names: validate.assertUniqueNames "DEFAULT ATTRS FILE" names);
        in ctx // {
          defaultAttrs = {
            flatShells = flatShells;
            variantsTree = variantsTree;
            shellNames = shellNames;
          };
        };

    # Main directory processor (pipeline architecture)
    processDirectory = currentPath: basePath:
      currentPath
      |> validate.assertFileExists  # Fail-fast path validation
      |> (path: layer.initialContext path basePath suffix)
      |> (ctx: validate.assertStructuralValidation ctx)
      |> (layer.processSubdirsAttrs currentPath basePath)
      |> (layer.processCommonAttrs currentPath basePath)
      |> (layer.processDefaultAttrs currentPath basePath)
      |> (ctx: validate.assertDefaultAttrsConflicts ctx)
      # Final layer state
      |> (ctx: {
        flatShells = ctx.subDirsAttrs.flatShells // ctx.commonAttrs.flatShells // ctx.defaultAttrs.flatShells;
        variantsTree = ctx.subDirsAttrs.variantsTree // ctx.commonAttrs.variantsTree // ctx.defaultAttrs.variantsTree;
        shellNames = ctx.subDirsAttrs.shellNames ++ ctx.commonAttrs.shellNames ++ ctx.defaultAttrs.shellNames;
      });
  };

  # == TOP-LEVEL EXECUTION ==
  rootResult = layer.processDirectory devDir "";

  # Global uniqueness validation (pipeline-style)
  _global_unique_validation = rootResult.shellNames
    |> (names: validate.assertUniqueNames "GLOBAL NAMESPACE" names);

in rootResult.flatShells


