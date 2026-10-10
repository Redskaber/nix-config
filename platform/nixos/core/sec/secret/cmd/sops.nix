# @path: ~/projects/configs/nix-config/platform/nixos/core/sec/secret/cmd/sops.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::sec::secret::cmd::sops

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [ sops ];

}
