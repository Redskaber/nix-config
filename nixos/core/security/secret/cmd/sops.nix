# @path: ~/projects/configs/nix-config/nixos/core/security/secret/cmd/sops.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::security::secret::cmd::sops


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [ sops ];

}


