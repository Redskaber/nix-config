# @path: ~/projects/configs/nix-config/home/core/sys/portal.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=hyprland
# @description: home::core::sys::portal
# - user portal config


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  # base(wayland)
  xdg.portal = {
    enable = !shared.isNixOS;
    xdgOpenUsePortal = true;

    config = {
      common.default = [ "gtk" ];
      ${shared.window-manager.tag}.default = shared.window-manager.value.portal.value.default;
    };

  extraPortals = shared.window-manager.value.portal.value.extraPortals;

  };

  # desktop portal
  home.packages = shared.window-manager.value.portal.value.extraPortals;

}


