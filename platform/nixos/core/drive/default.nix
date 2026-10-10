# @path: ~/projects/configs/nix-config/platform/nixos/core/drive/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::drive::default

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  # imports = [
  #   ./${shared.drive.tag}.nix
  # ];
  imports = builtins.map (drive: ./${drive}.nix) shared.drive.value;

}
