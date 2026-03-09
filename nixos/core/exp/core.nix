# @path: ~/projects/configs/nix-config/nixos/core/exp/core.nix
# @author: redskaber
# @datetime: 2026-03-01
# @description: nixos::core::exp::core

{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    curl git vim wget
    # sound
      # pamixer
      # pavucontrol
    # bluetooth
      # overskride
    # proxy
      # clash-verge-rev
  ];


}


