# @path: ~/projects/configs/nix-config/nixos/core/srv/db/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::db::default


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    ./mongodb.nix
    ./mysql.nix
    ./postgresql.nix
    ./redis.nix
  ];


}


