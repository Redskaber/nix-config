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
    # New: support inputsFrom for full composition
    inheritFrom ? [],
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
    # === Deduplicate inheritFrom by outPath ===
    # Filter out nulls and ensure each drv has an outPath
    validInheritFrom = builtins.filter (drv:
      drv != null && (builtins.hasAttr "outPath" drv)
    ) inheritFrom;
    # Use outPath as key for deduplication
    dedupedDrvMap = pkgs.lib.listToAttrs (
      map (drv: {
        name = builtins.hashString "sha256" drv.outPath;
        value = drv;
      }) validInheritFrom
    );
    dedupedInheritFrom = builtins.attrValues dedupedDrvMap;

    # === Extract from inputsFrom ===
    # We assume each item in inputsFrom is a derivation created by mkShell or mkDevShell
    # and may contain: buildInputs, nativeBuildInputs, shellHook
    extracted = map (drv:
      let
        attrs = drv.drvAttrs or {};
        bi = attrs.buildInputs or [];
        nbi = attrs.nativeBuildInputs or [];
        sh = attrs.shellHook or "";
      in {
        buildInputs = bi;
        nativeBuildInputs = nbi;
        shellHook = sh;
      }
    ) dedupedInheritFrom;
    mergedBuildInputs = buildInputs ++ (pkgs.lib.concatMap (x: x.buildInputs) extracted);
    mergedNativeBuildInputs = nativeBuildInputs ++ (pkgs.lib.concatMap (x: x.nativeBuildInputs) extracted);
    mergedShellHooks = pkgs.lib.concatStringsSep "\n" (map (x: x.shellHook) extracted);

    # execute hook functions
    callFn = fn:
      if fn != null
      then fn { inherit pkgs; }
      else "";
    # call hook functions
    finalPreInputs = preInputsHook  + (callFn preInputsHookFn);
    finalPostInputs= postInputsHook + (callFn postInputsHookFn);
    finalPreShell  = preShellHook   + (callFn preShellHookFn);
    finalPostShell = postShellHook  + (callFn postShellHookFn);
    # concat string sep
    fullShellHook = pkgs.lib.concatStringsSep "\n" (
      pkgs.lib.filter (line: line != "") [
        "# === Inherited shell hooks ==="
        mergedShellHooks
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
      "inheritFrom"
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


