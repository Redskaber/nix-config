# @path: ~/projects/nix-config/lib/dev-shells.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Utility to generate per-language dev shells from a directory


{ pkgs, inputs, suffix, devDir, commonModule ? null, ... }:
  let
    # List and filter dev files
    allFiles = builtins.attrNames (builtins.readDir devDir);
    langFiles = builtins.filter (name:
      pkgs.lib.hasSuffix suffix name && !pkgs.lib.hasPrefix "_" name
    ) allFiles;

    # Load common shell if provided
    commonShell =
      if commonModule != null
      then (import commonModule { inherit pkgs inputs; }).default
      else pkgs.mkShell {};

    # Build attrset: "c.nix" -> { name = "c"; value = shell }
    rawShells = pkgs.lib.genAttrs langFiles (file:
      let
        langName = pkgs.lib.removeSuffix suffix file;
        mod = import "${devDir}/${file}" {
          inherit pkgs inputs;
          common=commonShell;
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

    # Global default shell: merge all language shells' inputs
    allDefaultDerivations = builtins.attrValues langShells;
    globalDefault = pkgs.mkShell {
      inputsFrom = allDefaultDerivations;
      # optional other handler
    };

  in
    # Expose individual shells + golbal default
    langShells // { default = globalDefault; }



