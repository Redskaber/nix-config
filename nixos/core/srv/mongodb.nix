# @path: ~/projects/configs/nix-config/nixos/core/srv/mongodb.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::mongodb


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [ mongodb ];

}


