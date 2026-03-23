# @path: ~/projects/configs/nix-config/nixos/wm/niri/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::wm::niri
# - tty: niri --session
# - enable niri base

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

  # login window
  # services.displayManager.gdm.enable = true;

  environment.sessionVariables = {
    # For Electron apps to use wayland
    NIXOS_OZONE_WL = "1";
    # GTK app Wayland
    GDK_BACKEND = "wayland";
    # Electron app to wayland
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };


}


