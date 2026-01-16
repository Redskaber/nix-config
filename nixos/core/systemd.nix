# @path: ~/projects/configs/nix-config/nixos/core/systemd.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::systemd


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  systemd.services.flatpak-repo = {
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };
}


