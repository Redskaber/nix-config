# @path: ~/projects/configs/nix-config/home/core/exp/sys/misc/cava.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::misc::cava
# - terminal visucalizer audio (Decorations, Optional)


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
let
  cavaResult = shared.orc.mergeHomeFiles (
    shared.orc.listFilesRecursive inputs.cava-config ""
  ) [
    { include = [ "config" ];
      emitter = "copy";
      destPrefix = ".config/cava"; }
  ];
in
{
  home.packages = with pkgs; [ cava ];

  xdg.configFile."cava" = {
    source = inputs.cava-config;    # abs path
    recursive = true;               # rec-link
    force = true;
  };
  home.activation.cavaWallust = lib.hm.dag.entryAfter [ "writeBoundary" ] cavaResult.activation;

}


