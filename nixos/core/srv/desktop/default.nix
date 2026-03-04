# @path: ~/projects/configs/nix-config/nixos/core/srv/desktop/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::desktop::default


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    ./file-manage.nix
    ./flatpak.nix
  ];


}


