# @path: ~/projects/configs/nix-config/platform/nixos/core/sec/secret/cmd/ssh-to-pgp.nix
# @author: redskaber
# @datetime: 2026-02-26
# @description: platform::nixos::system::core::sec::secret::cmd::ssh-to-pgp

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [ ssh-to-pgp ];

}
