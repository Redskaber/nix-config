# @path: ~/projects/configs/nix-config/platform/nixos/core/sec/secret/cmd/ssh-to-age.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::sec::secret::cmd::ssh-to-age

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [ ssh-to-age ];

}
