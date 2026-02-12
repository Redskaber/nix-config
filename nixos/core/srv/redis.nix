# @path: ~/projects/configs/nix-config/nixos/core/srv/redis.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::redis


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [ redis ];

}


