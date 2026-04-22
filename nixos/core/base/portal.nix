# @path: ~/projects/configs/nix-config/nixos/core/base/portal.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=hyprland
# @description: nixos::core::base::portal


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
    enable = true;
    wlr.enable = true;
    xdgOpenUsePortal = true;

    config = {
      common.default = [ "gtk" ];
      ${shared.window-manager.tag}.default = shared.window-manager.value.portal.value.default;
    };

    extraPortals = shared.window-manager.value.portal.value.extraPortals pkgs;

  };

}


