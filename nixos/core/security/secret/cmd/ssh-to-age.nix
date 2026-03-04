# @path: ~/projects/configs/nix-config/nixos/core/security/secret/cmd/ssh-to-age.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::security::secret::cmd::ssh-to-age


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [ ssh-to-age ];

}


