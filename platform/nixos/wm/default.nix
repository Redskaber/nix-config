# @path: ~/projects/configs/nix-config/platform/nixos/wm/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::wm::default

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./${shared.window-manager.tag} ];

}
