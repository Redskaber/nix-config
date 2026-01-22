# @path: ~/projects/configs/nix-config/nixos/core/steam.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::steam
# - steam in nixos core, becuase steam need firewall and system mod exp


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  programs.steam.enable = true;
  programs.steam.protontricks.enable = true;

  # open Gamescope session（optimite & compat,  Wayland）
  programs.steam.gamescopeSession.enable = true;
  # Optional：custom Gamescope Params）
  # programs.steam.gamescopeSession.args = [ "-r" "144" "--force-grab-cursor" ];

  # open firewall（remotePlay,local-link)
  programs.steam.remotePlay.openFirewall = true;
  programs.steam.dedicatedServer.openFirewall = true;
  programs.steam.localNetworkGameTransfers.openFirewall = true;

  # extra Proton pkg（unoffice Proton game)）
  # programs.steam.extraCompatPackages = with pkgs; [
  #   proton-ge-custom
  # ];

  # add runtime depends）
  # programs.steam.extraPackages = with pkgs; [
  #   xorg.libXcursor
  #   xorg.libXi
  #   libva
  #   vulkan-loader
  # ];

  # Optional: open extest（used Steam inputer test）
  programs.steam.extest.enable = true;


}



