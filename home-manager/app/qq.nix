# @path: ~/projects/configs/nix-config/home-manager/app/qq.nix
# @author: redskaber
# @datetime: 2025-12-12


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  qq = config.lib.nixGL.wrap pkgs.qq;
  qq-no-sandbox = pkgs.writeShellScriptBin "qq" ''
    exec ${qq}/bin/qq --no-sandbox "$@"
  '';
in {
  home.packages = [
  qq-no-sandbox
  ];
}

