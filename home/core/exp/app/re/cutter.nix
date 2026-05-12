# @path: ~/projects/configs/nix-config/home/core/exp/app/re/cutter.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::re::cutter

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
let
  cutter-patched = shared.upkgs.cutter.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i \
        -e 's/\bSBK_CUTTERPLUGIN_IDX\b/SBK_CutterPlugin_IDX/g' \
        -e 's/\bSBK_CUTTERPLUGINMETADATA_IDX\b/SBK_CutterPluginMetadata_IDX/g' \
        src/plugins/PluginManager.cpp
    '';
  });
in
{
  home.packages = [ cutter-patched ];


}

