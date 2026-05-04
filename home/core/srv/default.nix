# @path: ~/projects/configs/nix-config/home/core/srv/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::srv::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./db
    ./notify
    ./security
  ];


}


