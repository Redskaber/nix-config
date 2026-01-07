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
        else
          throw "combinFrom entry is an attrset but has no 'default' and no shell config keys: ${toString (builtins.attrNames rawCfg)}"
      else
        throw "combinFrom entry must be an attrset (config or lang group), got: ${toString (builtins.typeOf rawCfg)}"
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
    mergedBuildInputs = buildInputs ++ (
      pkgs.lib.concatMap (x: x.buildInputs)
      extracted
    );
    mergedNativeBuildInputs = nativeBuildInputs ++ (
      pkgs.lib.concatMap (x: x.nativeBuildInputs)
      extracted
    );

    # hooks
    inheritedPreInputs  = pkgs.lib.concatStringsSep "\n" (map (x: x.preInputsHook) extracted);
    inheritedPostInputs = pkgs.lib.concatStringsSep "\n" (map (x: x.postInputsHook) extracted);
    inheritedPreShell   = pkgs.lib.concatStringsSep "\n" (map (x: x.preShellHook) extracted);
    inheritedPostShell  = pkgs.lib.concatStringsSep "\n" (map (x: x.postShellHook) extracted);
    inheritedShellHook  = pkgs.lib.concatStringsSep "\n" (map (x: x.shellHook) extracted);
    # execute hook functions
    callFn = fn:
      if fn != null
      then fn { inherit pkgs; }
      else "";
    # call hook functions
    finalPreInputs  = inheritedPreInputs  + "\n" + preInputsHook  + "\n" + (callFn preInputsHookFn);
    finalPostInputs = inheritedPostInputs + "\n" + postInputsHook + "\n" + (callFn postInputsHookFn);
    finalPreShell   = inheritedPreShell   + "\n" + preShellHook   + "\n" + (callFn preShellHookFn);
    finalPostShell  = inheritedPostShell  + "\n" + postShellHook  + "\n" + (callFn postShellHookFn);

    # concat string sep
    fullShellHook = pkgs.lib.concatStringsSep "\n" (
      pkgs.lib.filter (line: line != "") [
        "# === Inherited shellHook ==="
        inheritedShellHook
        "# === Own pre-inputs hook ==="
        finalPreInputs
        "# === Own post-inputs hook ==="
        finalPostInputs
        "# === Own pre-shell hook ==="
        finalPreShell
        "# === Own post-shell hook ==="
        finalPostShell
      ]
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


