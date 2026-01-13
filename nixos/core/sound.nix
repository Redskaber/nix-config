# @path: ~/projects/configs/nix-config/nixos/core/sound.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::sound


{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  # Enable sound.
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

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    # media-session.enable = true;
  };
  environment.systemPackages = with pkgs; [
    pamixer
    pavucontrol
  ];

}


