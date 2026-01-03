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
}: {

  programs.vscode.enable = true;

  # Used user config:
  xdg.configFile."vscode" = {
    source = inputs.vscode-config; # abs path
    recursive = true;              # rec-link
    force = true;
  };
}


