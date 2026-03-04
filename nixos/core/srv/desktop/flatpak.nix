# @path: ~/projects/configs/nix-config/nixos/core/srv/desktop/flatpak.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::desktop::flatpak


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{

  services = {
    # Flatpak app support
    flatpak.enable = true;
   };


}


