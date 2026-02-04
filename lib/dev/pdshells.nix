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
    assertAttrSet = context: value:
      value
      |> (v: if pkgs.lib.isAttrs v then v else throw ''
        INVALID STRUCTURE (${context}):
        • Expected: attrset
        • Got: ${builtins.typeOf v}
        Resolution: Ensure file returns an attrset like:
          { default = { buildInputs = [ ... ]; }; }
      '');

    assertUniqueNames = context: names:
      let
        dupes = names
          |> pkgs.lib.unique
          |> (uniqueNames: pkgs.lib.filter (n: pkgs.lib.count (x: x == n) names > 1) uniqueNames);
        report = dupes
          |> (d: if d == [] then null else throw ''
            ${context} NAMING CONFLICT:
            • Duplicate identifiers: ${builtins.concatStringsSep ", " d}
            Resolution: Follow naming protocol:
              - default.nix variant 'X' → [base]-X
              - X.nix variant 'default' → [base]-X (AVOID if [base]-X exists)
            Fix by renaming variants/files for global uniqueness.
          '');
      in names;

    assertFileExists = path:
      if builtins.pathExists path then path else throw ''
        PATH NOT FOUND: ${path}
        Resolution: Verify directory structure matches expectations.
      '';

    assertNoKeyConflicts = context: base: new:
      let
        conflicts = (builtins.attrNames new)
          |> (newKeys: pkgs.lib.filter (k: pkgs.lib.hasAttr k base) newKeys);
        _ = conflicts
          |> (c: if c != [] then throw ''
            ${context} KEY COLLISION:
            • Conflicting keys: ${builtins.concatStringsSep ", " c}
            • Base keys: ${builtins.concatStringsSep ", " (builtins.attrNames base)}
            • New keys: ${builtins.concatStringsSep ", " (builtins.attrNames new)}
            Resolution: Rename variants in default.nix or conflicting files/dirs.
          '' else null);
      in new;

  };

  # == CORE ARCHITECTURE PATTERNS ==
  # 1. Pipeline composition: |> for data transformation
  # 2. Layer isolation: pure functions with explicit context
  # 3. Early validation: fail-fast at source
  # 4. Semantic naming: decoupled naming strategy

  # == NAMING STRATEGY MODULE ==
  naming = {
    # Unified naming pipeline with pipe operators
    makeFullName = basePath: attrType: sourceName: variantName:
      ([
        (if basePath == "" then null else basePath)
        (if attrType == fs.attrType.Default then null else sourceName)
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
    attrType = {
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
      flatShells ? {},
      variantsTree ? {},
      shellNames ? {},
      subDirsAttrs ? layer.CommonAttrs {},
      commonAttrs ? layer.CommonAttrs {},
      defaultAttrs ? layer.CommonAttrs {}
    }: {
      currentPath = currentPath;
      basePath = basePath;
      flatShells = flatShells;
      variantsTree = variantsTree;
      shellNames = shellNames;
      subDirsAttrs = subDirsAttrs;
      commonAttrs = commonAttrs;
      defaultAttrs = defaultAttrs;
    };

    # Initial Context Function Callable
    initialContext = currentPath: basePath:
      (layer.Context { currentPath=currentPath; basePath=basePath; });

    # Structural validation pipeline
    structuralValidation = suffix: ctx:
      let
        entries = fs.listEntries ctx.currentPath;
        nixFiles = entries |> (e: pkgs.lib.filter (fs.isAttrsFile ctx.currentPath suffix) e);
        subDirs = entries |> (e: pkgs.lib.filter (fs.isSubDir ctx.currentPath) e);
        fileBases = nixFiles |> (files: map (f: pkgs.lib.removeSuffix suffix f) files);
        conflicts = fileBases |> (bases: pkgs.lib.filter (n: pkgs.lib.elem n subDirs) bases);
      in
        conflicts
        |> (c: if c != [] then throw ''
          STRUCTURAL AMBIGUITY in ${ctx.currentPath}:
          • Conflicting sources: ${builtins.concatStringsSep ", " c}
          Resolution: Maintain ONE source per base name:
            - EITHER file (${suffix}) OR directory
            - NOT both ${builtins.concatStringsSep " AND " (map (name: "${name}${suffix} vs ${name}/") c)}
          ''
          else null)
        |> (ignore: if nixFiles == [] && subDirs == [] then
          throw "EMPTY DIRECTORY: ${ctx.currentPath} requires .nix files or subdirs"
          else ctx);

    # Process subdirectories FIRST (depth-first)
    processSubdirsAttrs = currentPath: basePath: ctx:
      let
        subDirPaths = fs.listSubDirs currentPath;
        subResults = map (path:
          let
            newBase = if basePath == "" then path else "${basePath}-${path}";
            res = layer.processDirectory "${currentPath}/${path}" newBase;
          in {
            name = path;
            flatShells = res.flatShells;
            variantsTree = res.variantsTree;
            shellNames = res.shellNames;
          }
        ) subDirPaths;

        flatShells = subResults
          |> (results: pkgs.lib.foldl' (acc: r: acc // r.flatShells) {} results);
        variantsTree = subResults
          |> (results: pkgs.lib.listToAttrs (map (r: { name = r.name; value = r.variantsTree; }) results));
        shellNames = subResults
          |> (results: pkgs.lib.concatMap (r: r.shellNames) results);
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
            variants = (import filePath {
                inherit pkgs inputs;
                dev = ctx.subDirsAttrs.variantsTree;
              })
              |> (v: validate.assertAttrSet filePath v);  # Validation in pipeline

            flatShells = variants
              |> (vars: pkgs.lib.mapAttrs' (variantName: cfg:
                let
                  fullName = naming.makeFullName basePath fs.attrType.Common fileBase variantName;
                  shell = mkDevShell (cfg // { name = "dev-shell-${fullName}"; });
                in {
                  name = fullName;
                  value = shell;
                }
              ) vars);

            shellNames = builtins.attrNames flatShells;
          in {
            fileBase = fileBase;
            variants = variants;
            flatShells = flatShells;
            shellNames = shellNames;
          }
        ) attrsFiles;

        # Validate intra-layer collisions via pipeline
        localNames = fileResults
          |> (results: pkgs.lib.concatMap (r: r.shellNames) results)
          |> (names: validate.assertUniqueNames "NON-DEFAULT FILES" names);

        flatShells = fileResults
          |> (results: pkgs.lib.foldl' (acc: r: acc // r.flatShells) {} results);
        variantsTree = fileResults
          |> (results: pkgs.lib.listToAttrs (map (r: { name = r.fileBase; value = r.variants; }) results));
        shellNames = ctx.shellNames ++ localNames;
      in ctx // {
        commonAttrs = {
          flatShells = flatShells;
          variantsTree = variantsTree;
          shellNames = shellNames;
        };
        # Update context for next stage
        shellNames = shellNames;
        variantsTree = ctx.subDirsAttrs.variantsTree // variantsTree;
      };

    # Process default.nix LAST (default attrs file, full context: subdirs + non-default files)
    processDefaultAttrs = currentPath: basePath: ctx:
      if !(fs.hasDefaultAttrs currentPath) then ctx else
        let
          filePath = "${currentPath}/default.nix";
          # FULL CONTEXT: sees subdirs AND non-default files
          variants = (import filePath {
              inherit pkgs inputs;
              dev = ctx.variantsTree; # Full context
            })
            |> (v: validate.assertAttrSet filePath v);  # Pipeline validation

          flatShells = variants
            |> (vars: pkgs.lib.mapAttrs' (variantName: cfg:
              let
                fullName = naming.makeFullName basePath fs.attrType.Default "" variantName;
                shell = mkDevShell (cfg // { name = "dev-shell-${fullName}"; });
              in {
                name = fullName;
                value = shell;
              }
            ) vars);

          shellNames = builtins.attrNames flatShells
            |> (names: validate.assertUniqueNames "DEFAULT.NIX" (ctx.shellNames ++ names));

          # Prevent key collisions in variants tree
          _no_key_conflict_validation = validate.assertNoKeyConflicts "VARIANTS TREE" ctx.variantsTree variants
            |> (new: ctx.variantsTree // new);  # Safe merge

          mergedVariants = ctx.variantsTree // variants;
        in ctx // {
          defaultAttrs = {
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
      currentPath
      |> validate.assertFileExists  # Fail-fast path validation
      |> (path: layer.initialContext path basePath)
      |> (ctx: layer.structuralValidation suffix ctx)
      |> (layer.processSubdirsAttrs currentPath basePath)
      |> (layer.processCommonAttrs currentPath basePath)
      |> (layer.processDefaultAttrs currentPath basePath)
      # Final layer state
      |> (ctx: {
        flatShells = ctx.flatShells // ctx.subDirsAttrs.flatShells // ctx.commonAttrs.flatShells;
        variantsTree = ctx.variantsTree;
        shellNames = ctx.shellNames;
      });
  };

  # == TOP-LEVEL EXECUTION ==
  rootResult = layer.processDirectory devDir "";

  # Global uniqueness validation (pipeline-style)
  _global_unique_validation = rootResult.shellNames
    |> (names: validate.assertUniqueNames "GLOBAL NAMESPACE" names);

in rootResult.flatShells


