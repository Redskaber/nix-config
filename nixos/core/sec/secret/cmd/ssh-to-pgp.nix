# @path: ~/projects/configs/nix-config/nixos/core/sec/secret/cmd/ssh-to-pgp.nix
# @author: redskaber
# @datetime: 2026-02-26
# @description: nixos::core::sec::secret::cmd::ssh-to-pgp


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [ ssh-to-pgp ];

}


