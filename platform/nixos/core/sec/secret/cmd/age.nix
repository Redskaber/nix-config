# @path: ~/projects/configs/nix-config/platform/nixos/core/sec/secret/cmd/age.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::core::sec::secret::cmd::age

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [ age ];

}
