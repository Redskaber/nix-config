# @path: ~/projects/nix-config/lib/mk-dev-shells.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Utility to generate per-language dev shells from a directory
# @TODO: extend mkShell Hook.(preInputsHook, postInputsHook, preShellHook, postShellHook)


{ pkgs, ... }: {
  mkDevShell = {
    # base parameter
    name ? "dev-shell",
    buildInputs ? [],
    nativeBuildInputs ? [],
    # combin: combin From is now a list of CONFIG attrsets!
    combinFrom ? [],
    # Hook strings
    preInputsHook ? "",
    postInputsHook ? "",
    preShellHook ? "",
    postShellHook ? "",
    # Hook Functions
    preInputsHookFn ? null,
    postInputsHookFn ? null,
    preShellHookFn ? null,
    postShellHookFn ? null,
    # mkShell other parameters
    ...
  } @ args:
  let
    # === Smart resolve combinFrom entries ===
    resolvedCombinFrom = map (rawCfg:
      if pkgs.lib.isAttrs rawCfg then
        if builtins.hasAttr "default" rawCfg then
          # It's an attrset like { default = ..., full = ... } → use .default
          rawCfg.default
        else if builtins.hasAttr "buildInputs" rawCfg || builtins.hasAttr "shellHook" rawCfg then
          # It's already a config attrset (e.g. { buildInputs = ... })
          rawCfg
        else throw "combinFrom entry is an attrset but has no 'default' and no shell config keys: ${
          toString (builtins.attrNames rawCfg)
        }"
      else throw "combinFrom entry must be an attrset (config or lang group), got: ${
        toString (builtins.typeOf rawCfg)
      }"
    ) combinFrom;

    # Now extract from resolvedCombinFrom (each item is a config attrset)
    extracted = map (cfg: {
        buildInputs = cfg.buildInputs or [];
        nativeBuildInputs = cfg.nativeBuildInputs or [];
        shellHook = cfg.shellHook or "";
        # Hook: extract custom hooks
        preInputsHook = cfg.preInputsHook or "";
        postInputsHook = cfg.postInputsHook or "";
        preShellHook = cfg.preShellHook or "";
        postShellHook = cfg.postShellHook or "";
      }
    ) resolvedCombinFrom;
    mergedBuildInputs = pkgs.lib.unique(
      buildInputs ++ (
        pkgs.lib.concatMap (x: x.buildInputs)
        extracted
      )
    );
    mergedNativeBuildInputs = pkgs.lib.unique(
      nativeBuildInputs ++ (
        pkgs.lib.concatMap (x: x.nativeBuildInputs)
        extracted
      )
    );

    # === Enhanced hook function caller with name context ===
    callFn = fn: hookName:
      if fn == null then ""
      else let
          result = fn { inherit pkgs; };
        in if builtins.isString result
          then result
        else if result == null
          then ""
        else throw ''
          Hook function '${hookName}' returned non-string value.
          Expected: string
          Got: ${builtins.typeOf result}
          Value: ${
            if builtins.isAttrs result || builtins.isList result
              then "(complex value, see trace: use '--show-trace')"
            else builtins.toString result
          }
        '';

    # hooks
    inheritedPreInputs  = pkgs.lib.concatStringsSep "\n" (map (x: x.preInputsHook) extracted);
    inheritedPostInputs = pkgs.lib.concatStringsSep "\n" (map (x: x.postInputsHook) extracted);
    inheritedPreShell   = pkgs.lib.concatStringsSep "\n" (map (x: x.preShellHook) extracted);
    inheritedPostShell  = pkgs.lib.concatStringsSep "\n" (map (x: x.postShellHook) extracted);
    inheritedShellHook  = pkgs.lib.concatStringsSep "\n" (map (x: x.shellHook) extracted);
    # call hook functions
    finalPreInputs  = inheritedPreInputs  + "\n" + preInputsHook  + "\n" + (
      callFn preInputsHookFn "preInputsHookFn"
    );
    finalPostInputs = inheritedPostInputs + "\n" + postInputsHook + "\n" + (
      callFn postInputsHookFn "postInputsHookFn"
    );
    finalPreShell   = inheritedPreShell   + "\n" + preShellHook   + "\n" + (
      callFn preShellHookFn "preShellHookFn"
    );
    finalPostShell  = inheritedPostShell  + "\n" + postShellHook  + "\n" + (
      callFn postShellHookFn "postShellHookFn"
    );

    # === Build clean shellHook with conditional sections ===
    sections = [
      (if inheritedShellHook != ""  then "# === Inherited shellHook ===\n${inheritedShellHook}" else "")
      (if finalPreInputs != ""      then "# === Own pre-inputs hook ===\n${finalPreInputs}"     else "")
      (if finalPostInputs != ""     then "# === Own post-inputs hook ===\n${finalPostInputs}"   else "")
      (if finalPreShell != ""       then "# === Own pre-shell hook ===\n${finalPreShell}"       else "")
      (if finalPostShell != ""      then "# === Own post-shell hook ===\n${finalPostShell}"     else "")
    ];
    fullShellHook = pkgs.lib.concatStringsSep "\n\n" (
      pkgs.lib.filter (line: line != "") sections
    );

   # builder final make shell parameters
    mkShellArgs = (builtins.removeAttrs args [
      "combinFrom"
      "preInputsHook" "postInputsHook" "preShellHook" "postShellHook"
      "preInputsHookFn" "postInputsHookFn" "preShellHookFn" "postShellHookFn"
    ]) // {
      buildInputs = mergedBuildInputs;
      nativeBuildInputs = mergedNativeBuildInputs;
      shellHook = fullShellHook;
      inherit name;
    };
  in pkgs.mkShell mkShellArgs;
}


