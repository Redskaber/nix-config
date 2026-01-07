# @path: ~/projects/nix-config/lib/dev-shells.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Utility to generate per-language dev shells from a directory
# @TODO: extend mkShell Hook.(preInputsHook, postInputsHook, preShellHook)


{ pkgs, inputs, suffix, devDir, ... }:
  let
    inherit (import ./mk-dev-shell.nix { inherit pkgs; }) mkDevShell;

    # List and filter dev files
    allFiles = builtins.attrNames (builtins.readDir devDir);
    langFiles = builtins.filter (name:
      pkgs.lib.hasSuffix suffix name && !pkgs.lib.hasPrefix "_" name
    ) allFiles;

    # Build attrset: "c.nix" -> { name = "c"; value = shell }
    rawShells = pkgs.lib.genAttrs langFiles (file:
      let
        langName = pkgs.lib.removeSuffix suffix file;
        mod = import "${devDir}/${file}" {
          inherit pkgs inputs;
          dev = devDir;
          mkDevShell = mkDevShell;
        };
      in
        if pkgs.lib.isAttrs mod && pkgs.lib.hasAttr "default" mod
        then { inherit langName; shell = mod.default; }
        else throw "Module ${file} does not export a 'default' attribute"
    );

    # Convert to final attrset: { c = shell; rust = shell; ... }
    langShells = pkgs.lib.mapAttrs' (file: { langName, shell }:
      pkgs.lib.nameValuePair langName shell
    ) rawShells;

    # === Load explicit default.nix if it exists ===
    hasDefault = builtins.pathExists "${devDir}/default.nix";
    explicitDefault =
      if hasDefault
      then (import "${devDir}/default.nix" {
        inherit pkgs inputs devDir mkDevShell;
        # Pass the individual shells so default.nix can reference them
        dev = langShells;
      }).default
      else
        # Optional: fallback to auto-merge (or throw error)
        throw "No default.nix found in ${devDir}, and no fallback defined.";

  in
    # Expose individual shells + golbal default
    langShells // { default = explicitDefault; }



