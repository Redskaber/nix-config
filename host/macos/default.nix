# @path: ~/projects/configs/nix-config/host/macos/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: host::macos::default
# @directory: https://nix-community.github.io/home-manager/options.xhtml
# macOS standalone Home Manager entry point.


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home = {
    username = shared.user.username;
    homeDirectory = shared.homeDir;
    stateVersion = shared.version.value;
  };
  programs.home-manager.enable = true;

  imports = [
    ../../home/core
    ../../home/env
    ../../home/wm
  ];

  nixpkgs = shared.nixpkgs;

  systemd.user.startServices = "sd-switch";
}
