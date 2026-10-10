# @path: ~/projects/configs/nix-config/platform/nixos/core/base/sound.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::base::sound

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  # The local sound server is a policy fact, not a default (T10.1 —
  # the mechanical half of README known-debt #9): the sound enum's
  # rows answer "does this machine run one". `pipewire` is the
  # workstation form; `none` is the Null-Object row for console forms
  # where audio mediation, if any, belongs to the host environment
  # (WSLg's Windows-side pulse server; a QEMU device decision). The
  # gate reads the resolved fact — the T4.0 law — so a host
  # subtracts the whole stack by declaring a different row, never by
  # editing this file.
  config = lib.mkIf shared.sound.value.sound-server {
    # pipewire replaces pulseaudio wholesale (compat via pipewire-pulse).
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
      # If you want to use JACK applications, uncomment this
      # jack.enable = true;
    };

    # ALSA card state survives reboots.
    hardware.alsa.enablePersistence = true;

    # The mixer toolbelt rides the enum row (the wm/extraPortals
    # pattern): the none row carries an empty list, so this line is
    # unconditional.
    environment.systemPackages = shared.sound.value.mixers pkgs;
  };

}
