# @path: ~/projects/configs/nix-config/nixos/dm/ly/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::dm::ly::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  services.displayManager.ly = {
    enable = true;
    package = pkgs.ly;
    x11Support = true;
  };


}


