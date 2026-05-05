# @path: ~/projects/configs/nix-config/lib/shared/shared/fn.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: lib::shared::shared::fn
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
#
# Pure utility functions for the shared layer.
# All functions here are stateless and do not depend on pkgs or inputs.
# They operate only on the shared attrset values (enums, strings, lists).
#
# Design: dependency-free — importable at schema stage (phase 1) without pkgs.

{ inputs
, enum
, const
, schema
, ...
}:
let
  # Check whether a platform tag is NixOS.
  # Usage: fn.isNixOS shared.platform
  isNixOS = platform: platform == enum.platform.nixos;

  # Check whether a platform tag is a standalone Linux (non-NixOS).
  # Usage: fn.isLinux shared.platform
  isLinux = platform: platform == enum.platform.linux;

  # Check whether a platform tag is macOS.
  # Usage: fn.isMacOS shared.platform
  isMacOS = platform: platform == enum.platform.macos;

  # Check whether a platform tag is WSL.
  # Usage: fn.isWSL shared.platform
  isWSL = platform: platform == enum.platform.wsl;

  # Derive the home directory path for a given platform and username.
  # NixOS/Linux/WSL → /home/<user>
  # macOS           → /Users/<user>
  # Usage: fn.homeDir shared.platform shared.user.username
  homeDir = platform: username:
    if isMacOS platform
    then "/Users/${username}"
    else "/home/${username}";

  # Build a sops secret file path from the secrets attrset value.
  # Usage: fn.sopsFile self secretBase secretRel
  #   secretRel: e.g. "nixos/core/base/user/kilig/password"
  sopsFile = self: secretBase: secretRel: "${self}/${secretBase}/${secretRel}.yaml";

  # Build a sops secret file path for runtime path use
  sopsRuntimePath = rbase: rpath: "${rbase}/${rpath}";
in {
  inherit
    isNixOS
    isMacOS
    isLinux
    isWSL
    homeDir
    sopsFile
    sopsRuntimePath
  ;
}

