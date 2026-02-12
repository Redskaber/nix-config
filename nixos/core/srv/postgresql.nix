# @path: ~/projects/configs/nix-config/nixos/core/srv/postgresql.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::postgresql


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [ postgresql ];

}


