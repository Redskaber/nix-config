# @path: ~/projects/configs/nix-config/home/core/app/kitty.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::kitty
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.kitty.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
let
  kittyResult = shared.orc.mergeHomeFiles (
    shared.orc.listFilesRecursive inputs.kitty-config ""
  ) [
    { include = [ "kitty-themes/01-Wallust.conf" ];
      emitter = "copy";
      destPrefix = ".config/kitty"; }
  ];
in
{

  programs.kitty = {
    enable = true;
    package = pkgs.kitty;
    # package = config.lib.nixGL.wrap pkgs.kitty;   # non-nixos
  };

  # Used user config:
  xdg.configFile."kitty" = {
    source = inputs.kitty-config;   # abs path
    recursive = true;               # rec-link
    force = true;
  };
  home.activation.kittyWallust = lib.hm.dag.entryAfter [ "writeBoundary" ] kittyResult.activation;

}


