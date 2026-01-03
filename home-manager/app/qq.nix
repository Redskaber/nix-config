# @path: ~/projects/nix-config/home-manager/app/qq.nix
# @author: redskaber
# @datetime: 2025-12-12


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  core = pkgs.qq;
in {

  home.packages = [
    (pkgs.writeShellScriptBin "qq" ''
      # Point GTK to the correct module directory
      export GTK_PATH=${pkgs.libcanberra}/lib/gtk-3.0
      export GTK_MODULES=canberra-gtk-module

      # Also ensure libcanberra is in library path (just in case)
      export LD_LIBRARY_PATH="${pkgs.libcanberra}/lib:$LD_LIBRARY_PATH"

      exec ${pkgs.qq}/bin/qq --no-sandbox "$@"
    '')
  ];
}

