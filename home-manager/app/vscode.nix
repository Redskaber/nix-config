# @path: ~/projects/nix-config/home-manager/app/vscode.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.vscode.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  vscode-no-sandbox = pkgs.writeShellScriptBin "code" ''
    exec ${pkgs.vscode}/bin/code --no-sandbox "$@"
  '';
in {

  # programs.vscode.enable = true;

  home.packages = [ vscode-no-sandbox ];

  # Used user config:
  xdg.configFile."Code/User" = {
    source = inputs.vscode-config; # abs path
    recursive = true;              # rec-link
    force = true;
  };

}



