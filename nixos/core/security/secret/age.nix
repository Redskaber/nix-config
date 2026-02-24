# @path: ~/projects/configs/nix-config/nixos/core/security/secret/age.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::security::secret::age


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [ age ];

}


