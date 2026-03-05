# @path: ~/projects/configs/nix-config/nixos/wm/niri/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::wm::niri


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  programs.niri = {
    enable = true;
    package = pkgs.niri;
    useNautilus = false;
  };

}


