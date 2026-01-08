# @path: ~/projects/nix-config/lib/dev-shells.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Utility to generate per-language dev shells from a directory
# @Supports: nix develop .#<system>.<lang>.<variant>
# @TODO: extend mkShell Hook.(preInputsHook, postInputsHook, preShellHook)


{ pkgs, inputs, devDir, suffix ? ".nix", ... }:
  let
    inherit (import ./mk-dev-shell.nix { inherit pkgs; }) mkDevShell;

    # List and filter dev files
    allFiles = builtins.attrNames (builtins.readDir devDir);
    langFiles = builtins.filter (name:
      pkgs.lib.hasSuffix suffix name &&
      !pkgs.lib.hasPrefix "_" name &&
      name != "default.nix"
    ) allFiles;

    # Step 1: Load each lang file → returns attrset like { default = ..., full = ... }
    langConfigsRaw = pkgs.lib.genAttrs langFiles (file:
      let
        mod = import "${devDir}/${file}" {
          inherit pkgs inputs;
          dev = devDir;
        };
      in
        if pkgs.lib.isAttrs mod
          then mod
        else throw "Module ${file} must return an attrset"
    );

    # Step 2: Rename keys: "python.nix" → "python"
    langConfigs = pkgs.lib.mapAttrs' (file:
      value: pkgs.lib.nameValuePair (
        pkgs.lib.removeSuffix suffix file
      ) value
    ) langConfigsRaw;

    # Step 3: Flatten lang.variants into top-level names like "python", "python-machine"
    # Custom flatten for lang.variants (no flattenTree needed)
    flattenLangVariants = attrs:
      pkgs.lib.concatMapAttrs (langName: variants:
        if !pkgs.lib.isAttrs variants then
          throw "Expected attrset for ${langName}, got ${builtins.typeOf variants}"
        else
          pkgs.lib.mapAttrs' (variantName: cfg:
            let
              key =
                if variantName == "default"
                  then langName
                else "${langName}-${variantName}";
            in
              pkgs.lib.nameValuePair key cfg
          ) variants
      ) attrs;
    langShellsFlat = flattenLangVariants (
      pkgs.lib.mapAttrs (langName:
        variants: pkgs.lib.mapAttrs (variantName:
          cfg: mkDevShell (
            cfg // {
              name = "dev-shell-${
                if variantName == "default"
                  then langName
                else "${langName}-${variantName}"
              }";
            }
          )
        ) variants
      ) langConfigs
    );

    # Step 4: Handle top-level default.nix (if exists)
    hasDefault = builtins.pathExists "${devDir}/default.nix";
    topLevelShells =
      if hasDefault
        then let
          mod = import "${devDir}/default.nix" {
            inherit pkgs inputs;
            # Pass the individual shells so default.nix can reference them
            dev = langConfigs;
          };
          # Assume default.nix returns { default = { ... }, minimal = { ... } }
          shells = pkgs.lib.mapAttrs (name:
            cfg: mkDevShell (
              cfg // { name = "top-dev-shell-${name}"; }
            )
          ) mod;
        in shells
      # Optional: allow flake to work without default.nix
      else {};

  in
    # Final output: only flat derivations!
    topLevelShells // langShellsFlat

