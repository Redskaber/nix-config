# @path: ~/projects/configs/nix-config/nixos/core/base/systemd.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::base::systemd


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  systemd.services.flatpak-repo = {
    description = "Add Flathub remote for Flatpak";
    # Oneshot: triggered manually via `just service-start flatpak-repo`
    # or on first boot via activation script
    wantedBy = lib.mkForce [];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };
}


