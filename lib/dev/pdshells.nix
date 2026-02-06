# @path: ～/projects/configs/nix-config/lib/dev/pdshells.nix
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
      (builtins.groupBy (x: x) names) # O(n)
      |> (groups: pkgs.lib.filterAttrs (_: g: builtins.length g > 1) groups)  # O(m)
      |> (dupGroups: builtins.attrNames dupGroups)
      |> (dupNames: if dupNames == [] then names else throw ''
          ${context} NAMING CONFLICT:
          • Duplicate identifiers: ${builtins.concatStringsSep ", " dupNames}
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

    # Pipeline checker for pipeline build variantsTree
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
        nixFiles = pkgs.lib.filter (fs.isAttrsFile ctx.currentPath ctx.suffix) entries;
        subDirs = pkgs.lib.filter (fs.isSubDir ctx.currentPath) entries;
        fileBases = map (f: pkgs.lib.removeSuffix ctx.suffix f) nixFiles;
        conflicts = pkgs.lib.filter (n: pkgs.lib.elem n subDirs) fileBases;
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
    default-variantName = "default";
    default-concat-sep = "-";
    # Unified naming pipeline with pipe operators
    # @basePath: string
    # @attrType: enum::AttrType
    # @fileBase: string
    # @variantName: string
    makeFullName = basePath: attrType: fileBase: variantName:
      ([
        (if basePath == fs.default-basePath then null else basePath)
        (if attrType == fs.AttrType.Default then null else fileBase)
        (if variantName == naming.default-variantName then null else variantName)
      ]
      |> pkgs.lib.filter (x: x != null))                      # Remove empty parts
      |> pkgs.lib.concatStringsSep naming.default-concat-sep  # Join with hyphens
      |> (fullName: if fullName == "" then naming.default-variantName else fullName); # Handle empty case
  };

  # == FILESYSTEM MODULE (pure path operations) ==
  fs = {
    default-nix = "default.nix";
    default-fileBase = "";
    default-basePath = "";
    default-private-prefix = "_";
    # Since Nix lacks native support for data structures,
    # we utilize native datasets and employ a contract-based approach to simulate enums,
    # aiming for clearer semantic expression.
    AttrType = {
      Default = 0;
      Common  = 1;
    };

    # Curried type checkers (pipeline-ready)
    isPrivate = name: (pkgs.lib.hasPrefix fs.default-private-prefix name);
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
      |> (entries: pkgs.lib.filter (name: name != fs.default-nix && fs.isAttrsFile path suffix name) entries);

    hasDefaultAttrs = path:
      (fs.listEntries path)
      |> (entries: pkgs.lib.any (name: name == fs.default-nix) entries);

    # Single file attrs mapAttrs' and flat shells
    # @basePath: string
    # @attrType: AttrType
    # @fileBase: string
    # @variantsTree: { ... }
    flatShellsMapAttrs' = basePth: attrType: fileBase: variantsTree:
      pkgs.lib.mapAttrs' (variantName: attrsetCfg:
        (naming.makeFullName basePth attrType fileBase variantName)
        |> (name: {
          name = name;
          value = mkDevShell (attrsetCfg // { name = "dev-shell-${name}"; });
        })
      ) variantsTree;

    # Get file base
    # @suffix: string
    # @fileName: string
    getFileBase = suffix: fileName: pkgs.lib.removeSuffix suffix fileName;

    # Read file attrsets
    readFileAttrs = filePath: pkgs: inputs: variantsTree:
      (import filePath { inherit pkgs inputs; dev = variantsTree; })
      |> (vars: validate.assertAttrSet "FILE CONTENT (${filePath})" vars);
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
      variantsTree ? {},
      shellNames ? [],
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
      defaultAttrs ? layer.CommonAttrs {},
    }: {
      currentPath = currentPath;
      basePath = basePath;
      suffix = suffix;
      subDirsAttrs = subDirsAttrs;
      commonAttrs = commonAttrs;
      defaultAttrs = defaultAttrs;
    };

    # Initial Context Function Callable
    # @currentPath: string
    # @basePath: string
    # @suffix: string
    initialContext = currentPath: basePath: suffix:
      (layer.Context { currentPath=currentPath; basePath=basePath; suffix=suffix; });

    # Layer result data schema
    # @path: string
    # ...
    LayerResult = {
      path,
      flatShells,
      variantsTree,
      shellNames
    }: {
      path = path;
      flatShells = flatShells;
      variantsTree = variantsTree;
      shellNames = shellNames;
    };

    #Initial LayerResult Function Callable
    # @currentPath: string
    # @basePath: string
    # @path: string
    initialLayerResult = currentPath: basePath: path: ctx:
      (if basePath == fs.default-basePath then path else "${basePath}-${path}")
      |>(newBasePath: layer.processDirectory "${currentPath}/${path}" newBasePath ctx)
      |>(res: layer.LayerResult {
        path = path;
        flatShells = res.flatShells;
        variantsTree = res.variantsTree;
        shellNames = res.shellNames;
      });

    # File result date schema
    FileResult = {
      fileBase,
      flatShells,
      variantsTree,
      shellNames,
    }: {
      fileBase = fileBase;
      flatShells = flatShells;
      variantsTree = variantsTree;
      shellNames = shellNames;
    };

    # File constract schema
    FileContext = {
      currentPath,
      basePath,
      attrType,
      fileName,
      subVariantsTree,
      inputs,
      suffix ? ".nix",
      pkgs ? import <nixpkgs> {},
    }: {
      currentPath = currentPath;
      basePath = basePath;
      attrType = attrType;
      fileName = fileName;
      subVariantsTree = subVariantsTree;
      inputs = inputs;
      suffix = suffix;
      pkgs = pkgs;
    };

    # Initial FileResult Function Callsble
    # @fileCtx: FileContext
    # @return: FileResult
    initialFileResult = fileCtx:
      let
        fileBase = fs.getFileBase fileCtx.suffix fileCtx.fileName;
        filePath = "${fileCtx.currentPath}/${fileCtx.fileName}";
        variantsTree = fs.readFileAttrs filePath fileCtx.pkgs fileCtx.inputs fileCtx.subVariantsTree;
        flatShells = fs.flatShellsMapAttrs' fileCtx.basePath fileCtx.attrType fileBase variantsTree;
        shellNames = builtins.attrNames flatShells;
      in layer.FileResult {
        fileBase = fileBase;  # Used common attrs files mapping'
        flatShells = flatShells;
        variantsTree = variantsTree;
        shellNames = shellNames;
      };

    FileProcessStrategy = {
      # File handle strategy protocol
      # @attrType: AttrType
      # @targetField: string
      # @fn-getFileList: |string, string| -> [ string ]
      # @fn-getSubVariantsTree: |Context| -> variantsTree
      # @fn-aggregateVariantsTree: |[FileResult]| -> attrset { ... }
      # @fn-validationContext: |string| -> string
      FileStrategy = {
        attrType,
        targetField,
        fn-getFileList,
        fn-getSubVariantsTree,
        fn-aggregateVariantsTree,
        fn-validationContext,
      }: {
        attrType = attrType;
        targetField = targetField;
        fn-getFileList = fn-getFileList;
        fn-getSubVariantsTree = fn-getSubVariantsTree;
        fn-aggregateVariantsTree = fn-aggregateVariantsTree;
        fn-validationContext = fn-validationContext;
      };

      CommonStrategy = layer.FileProcessStrategy.FileStrategy {
        attrType = fs.AttrType.Common;
        targetField = "commonAttrs";
        fn-getFileList = currentPath: suffix: fs.listAttrsFiles currentPath suffix;
        fn-getSubVariantsTree = ctx: ctx.subDirsAttrs.variantsTree;
        fn-validationContext = currentPath: "COMMON ATTRS FILES(${currentPath})";
        fn-aggregateVariantsTree = fileResults: pkgs.lib.listToAttrs (map (r: { name = r.fileBase; value = r.variantsTree; }) fileResults);
      };

      DefaultStrategy = layer.FileProcessStrategy.FileStrategy {
        attrType = fs.AttrType.Default;
        targetField = "defaultAttrs";
        fn-getFileList = currentPath: suffix: if fs.hasDefaultAttrs currentPath then [ fs.default-nix ] else [];
        fn-getSubVariantsTree = ctx: ctx.subDirsAttrs.variantsTree // ctx.commonAttrs.variantsTree;
        fn-validationContext = currentPath: "DEFAULT ATTRS FILE(${currentPath})";
        fn-aggregateVariantsTree = fileResults: (builtins.head fileResults).variantsTree;
      };

      fn-execute = strategy: currentPath: basePath: ctx:
        (strategy.fn-getFileList currentPath ctx.suffix)
        |>(files: if files == []
          then ctx
          else (
            map (fileName: layer.initialFileResult (layer.FileContext {
                inherit currentPath basePath pkgs inputs fileName;
                attrType = strategy.attrType;
                suffix = ctx.suffix;
                subVariantsTree = strategy.fn-getSubVariantsTree ctx;
            })) files
            |> (fileResults: {
              variantsTree = (strategy.fn-aggregateVariantsTree fileResults);
              flatShells   = (pkgs.lib.foldl' (acc: r: acc // r.flatShells) {} fileResults);
              shellNames   = (pkgs.lib.concatMap (r: r.shellNames) fileResults)
                |> (names: validate.assertUniqueNames (strategy.fn-validationContext currentPath)  names);
            })
            |> (attrs: ctx // { ${strategy.targetField} = attrs; })
          )
        );
    };

    # Process subdirectories FIRST (depth-first)
    # @currentPath: string
    # @basePath: string
    # @ctx: Context
    processSubDirsAttrs = currentPath: basePath: ctx:
      let
        subDirPaths = fs.listSubDirs currentPath;
        subResults = map (path: layer.initialLayerResult currentPath basePath path ctx) subDirPaths;
        flatShells = pkgs.lib.foldl' (acc: r: acc // r.flatShells) {} subResults;
        variantsTree = pkgs.lib.listToAttrs (map (r: { name = r.path; value = r.variantsTree; }) subResults);
        shellNames = (pkgs.lib.concatMap (r: r.shellNames) subResults)
          |> (names: validate.assertUniqueNames "SUB DIRECTORY ATTRS(${currentPath})" names);
      in ctx // {
        subDirsAttrs = {
          flatShells = flatShells;
          variantsTree = variantsTree;
          shellNames = shellNames;
        };
      };

    # Process non-default files (common attrs files, isolated context: sees ONLY subdirs)
    # @currentPath: string
    # @basePath: string
    # @ctx: Context
    processCommonAttrs = currentPath: basePath: ctx:
      layer.FileProcessStrategy.fn-execute layer.FileProcessStrategy.CommonStrategy currentPath basePath ctx;

    # Process default.nix LAST (default attrs file, full context: subdirs + non-default files)
    # @currentPath: string
    # @basePath: string
    # @ctx: Context
    processDefaultAttrs = currentPath: basePath: ctx:
      layer.FileProcessStrategy.fn-execute layer.FileProcessStrategy.DefaultStrategy currentPath basePath ctx;

    # Directory processor (pipeline architecture)
    # @currentPath: string
    # @basePath: string
    processDirectory = currentPath: basePath: ctx:
      ctx
      |> (ctx: validate.assertStructuralValidation ctx)
      |> (ctx: layer.processSubDirsAttrs currentPath basePath ctx)
      |> (ctx: layer.processCommonAttrs currentPath basePath ctx)
      |> (ctx: layer.processDefaultAttrs currentPath basePath ctx)
      |> (ctx: validate.assertDefaultAttrsConflicts ctx)
      # Final layer state -> layer.LayerResult res
      |> (ctx: {
        flatShells   = ctx.subDirsAttrs.flatShells   // ctx.commonAttrs.flatShells   // ctx.defaultAttrs.flatShells;
        variantsTree = ctx.subDirsAttrs.variantsTree // ctx.commonAttrs.variantsTree // ctx.defaultAttrs.variantsTree;
        shellNames   = ctx.subDirsAttrs.shellNames   ++ ctx.commonAttrs.shellNames   ++ ctx.defaultAttrs.shellNames;
      });

    # Main processor
    # @currentPath: string
    # @basePath: string
    # @suffix: string
    processMain = currentPath: basePath: suffix:
      (validate.assertFileExists currentPath) # Fail-fast path validation
      |> (path: layer.initialContext path basePath suffix)
      |> (ctx: layer.processDirectory currentPath basePath ctx);
  };

  # == TOP-LEVEL EXECUTION ==
  rootResult = layer.processMain devDir fs.default-basePath suffix;

  # Global uniqueness validation (pipeline-style)
  _global_unique_validation = rootResult.shellNames
    |> (names: validate.assertUniqueNames "GLOBAL NAMESPACE" names);

in rootResult.flatShells


