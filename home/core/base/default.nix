# @path: ~/projects/configs/nix-config/home/core/base/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::base::default

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{

  imports = [
    ./fonts.nix
    ./i18n.nix
    ./portal.nix
    # WSL user-space specialisation (T7.1) — caps.wsl-gated: the
    # shared-tree address for wslview/WSLENV interop, consumed by
    # every wsl-capable host (standalone-wsl and nixos-wsl alike).
    ./wsl.nix
    ./xdg.nix
  ];

}
