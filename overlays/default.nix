# @path: ~/projects/configs/nix-config/overlays/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: overlays::default


# This file defines overlays
{ shared, ... }: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  patches = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
    cutter_patched = shared.upkgs.cutter.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        sed -i \
          -e 's/\bSBK_CUTTERPLUGIN_IDX\b/SBK_CutterPlugin_IDX/g' \
          -e 's/\bSBK_CUTTERPLUGINMETADATA_IDX\b/SBK_CutterPluginMetadata_IDX/g' \
          src/plugins/PluginManager.cpp
        '';
    });


  };


}


