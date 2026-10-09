# @path: ~/projects/configs/nix-config/platform/nixos/dm/sddm/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::system::dm::sddm::default

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  services.displayManager = {
    enable = true;
    sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm;
      extraPackages = [ ];
      enableHidpi = true;
      autoNumlock = false;
      autoLogin = {
        relogin = false;
        minimumUid = 1000;
      };
      wayland = {
        enable = true;
        compositor = "weston";
      };
    };
  };

}
