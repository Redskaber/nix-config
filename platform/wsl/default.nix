# @path: ~/projects/configs/nix-config/platform/wsl/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: platform::wsl::default
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# Platform dispatch: routes to arch-specific entry via shared.arch.tag.
# Consistent with platform/nixos/ and platform/linux/ structure.


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./${shared.arch.tag}.nix
  ];
}
